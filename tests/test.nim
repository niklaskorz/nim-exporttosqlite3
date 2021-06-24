import unittest
import sugar
import math
import db_sqlite
import exporttosqlite3

proc myNimFunction(greeting: string, name: string, age: int32): string {.exportToSqlite3.} =
  if name == "Peter Parker":
    raise ValueError.newException("oh damn")
  greeting & " " & name & " (age " & $age & ")"

proc isOld(age: int32): bool {.exportToSqlite3.} = age > 20

proc squareRoot(value: float): float {.exportToSqlite3.} = sqrt(value)

test "can run exported functions in UPDATE":
  let db = open("test.db", "", "", "")
  defer:
    db_sqlite.close(db)
  db.registerFunctions()
  db.exec(sql"DROP TABLE IF EXISTS students")
  db.exec(sql"CREATE TABLE students (name TEXT, age INT)")
  db.exec(sql"INSERT INTO students (name, age) VALUES (?, ?), (?, ?)",
      "Peter Parker", 23, "John Good", 19)
  db.exec(sql"UPDATE students SET name = myNimFunction('Hello', name, age)")
  var names = collect(newSeq):
    for row in db.instantRows(sql"SELECT name FROM students"):
      row[0]
  check names == @[
    "Hello Peter Parker (age 23)",
    "Hello John Good (age 19)"
  ]

test "can use exported functions in SELECT":
  let db = open("test.db", "", "", "")
  defer:
    db_sqlite.close(db)
  db.registerFunctions()
  db.exec(sql"DROP TABLE IF EXISTS students")
  db.exec(sql"CREATE TABLE students (name TEXT, age INT)")
  db.exec(sql"INSERT INTO students (name, age) VALUES (?, ?), (?, ?)",
      "Peter Parker", 23, "John Good", 19)
  var squareRoots = collect(newSeq):
    for row in db.instantRows(sql"SELECT squareRoot(age) FROM students WHERE isOld(age)"):
      row[0]
  check squareRoots == @["4.79583152331272"]
