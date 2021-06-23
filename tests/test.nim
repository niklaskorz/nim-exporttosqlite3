import unittest
import sugar
import db_sqlite
import exporttosqlite3

proc myNimFunction(greeting: string, name: string, age: int32): string {.exportToSqlite3.} =
  greeting & " " & name & " (age " & $age & ")"

test "can run exported functions in sqlite3":
  let db = open("test.db", "", "", "")
  defer:
    db_sqlite.close(db)
  db.registerFunctions()
  db.exec(sql"DROP TABLE IF EXISTS students")
  db.exec(sql"CREATE TABLE students (name TEXT, age INT)")
  db.exec(sql"INSERT INTO students (name, age) VALUES (?, ?), (?, ?)",
      "Peter Parker", 23, "John Good", 19)
  db.exec(sql"UPDATE students SET name = myNimFunction('Hello', name, age)")
  var columns: DbColumns
  var names = collect(newSeq):
    for row in db.instantRows(columns, sql"SELECT name FROM students"):
      row[0]
  check names == @[
    "Hello Peter Parker (age 23)",
    "Hello John Good (age 19)"
  ]
