# `exportToSqlite3`

Export Nim functions to your sqlite3 database instance without worrying about boilerplate code.

## Installation

Add the package to your `<project>.nimble` file:

```nim
requires "exporttosqlite3 == 0.2.0"
```

## Usage

```nim
import exporttosqlite3
import db_sqlite

proc myNimFunction(greeting: string, name: string, age: int32): string {.exportToSqlite3.} =
  greeting & " " & name & " (age " & $age & ")"

when isMainModule:
  let db = open("test.db", "", "", "")
  defer:
    db_sqlite.close(db)
  db.registerFunctions()
  db.exec(sql"DROP TABLE IF EXISTS students")
  db.exec(sql"CREATE TABLE students (name TEXT, age INT)")
  db.exec(sql"INSERT INTO students (name, age) VALUES (?, ?), (?, ?)",
      "Peter Parker", 23, "John Good", 19)
  db.exec(sql"UPDATE students SET name = myNimFunction('Hello', name, age)")
```

## Supported data types

The following data types are supported for parameters and returns:

- `cstring`
- `string` (internally converted from/to `cstring`)
- `int32`
- `int64`
- `float64`
- `float` (alias for `float64`)
- `bool` (internally converted from/to `int32`)

## Error handling

Exceptions are catched by the generated wrapper function and forwarded to sqlite through `sqlite3_result_error`.
They can be catched as `DbError` in Nim, but only contain the original exception as a string representation.
