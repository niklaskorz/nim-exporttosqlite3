import macros
import sqlite3

export sqlite3

var registrationFunctions: seq[proc(db: PSqlite3): int32]

macro exportToSqlite3*(input: untyped): untyped =
  template paramString(identifier, argIndex): untyped =
    let identifier = $value_text(argv[argIndex])
  template paramInt32(identifier, argIndex): untyped =
    let identifier = value_int(argv[argIndex])
  template paramInt64(identifier, argIndex): untyped =
    let identifier = value_int64(argv[argIndex])
  template resultString(): untyped =
    context.result_text(nimResult, int32(nimResult.len), nil)
  template resultInt32(): untyped =
    context.result_int(nimResult)
  template resultInt64(): untyped =
    context.result_int64(nimResult)

  assert input.kind == nnkProcDef
  let ident = input[0]
  assert ident.kind == nnkIdent
  let params = input[3]
  assert params.kind == nnkFormalParams

  let wrapperBody = newStmtList()
  var callArgs: seq[NimNode]
  var paramIndex = 0
  for param in params[1..^1]:
    assert param.kind == nnkIdentDefs
    assert param[0].kind == nnkIdent
    assert param[1].kind == nnkIdent
    if eqIdent(param[1], "string"):
      wrapperBody.add(getAst(paramString(param[0], paramIndex)))
    elif eqIdent(param[1], "int32"):
      wrapperBody.add(getAst(paramInt32(param[0], paramIndex)))
    elif eqIdent(param[1], "int64"):
      wrapperBody.add(getAst(paramInt64(param[0], paramIndex)))
    else:
      error "parameter type `" & strVal(param[1]) & "` cannot be exported to sqlite3", param[1]
    callArgs.add(param[0])
    paramIndex += 1

  var call = newCall(ident, callArgs)
  wrapperBody.add(newLetStmt(ident"nimResult", call))

  let returnType = params[0]
  assert returnType.kind == nnkIdent
  if eqIdent(returnType, "string"):
    wrapperBody.add(getAst(resultString()))
  elif eqIdent(returnType, "int32"):
    wrapperBody.add(getAst(resultInt32()))
  elif eqIdent(returnType, "int64"):
    wrapperBody.add(getAst(resultInt64()))
  else:
    error "return type `" & strVal(returnType) & "` cannot be exported to sqlite3", returnType

  let wrapperIdent = newIdentNode("exportToSqlite3_" & strVal(ident))
  let wrapperArgs = [
    newEmptyNode(),
    newIdentDefs(ident"context", ident"Pcontext"),
    newIdentDefs(ident"argc", ident"int32"),
    newIdentDefs(ident"argv", ident"PValueArg"),
  ]
  let wrapperPragmas = newTree(nnkPragma, ident"cdecl")
  let wrapper = newProc(wrapperIdent, wrapperArgs, wrapperBody, nnkProcDef, wrapperPragmas)

  let registerIdent = newIdentNode("registerSqlite3_" & strVal(ident))
  let registerArgs = [
    ident"int32",
    newIdentDefs(ident"db", ident"PSqlite3"),
  ]
  let registerBody = newStmtList(newCall(
    ident"create_function",
    ident"db",
    newStrLitNode(strVal(ident)), # name of the function in SQL
    newIntLitNode(paramIndex), # parameter count (-1 for varargs)
    ident"SQLITE_UTF8", # encoding of text values
    newNilLit(), # user data pointer
    wrapperIdent, # scalar function
    newNilLit(), # step function
    newNilLit(), # finalize function
  ))
  let register = newProc(registerIdent, registerArgs, registerBody)

  let addRegistrationFunction = newCall(ident"addRegistrationFunction", registerIdent)

  result = newStmtList()
  result.add(input)
  result.add(wrapper)
  result.add(register)
  result.add(addRegistrationFunction)

proc addRegistrationFunction*(register: proc(db: PSqlite3): int32) =
  registrationFunctions.add(register)

proc registerFunctions*(db: PSqlite3) =
  for register in registrationFunctions:
    discard register(db)
