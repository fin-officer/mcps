import sqlite3

conn = sqlite3.connect('mcp_server/data/database.db')
cursor = conn.cursor()

# Tworzenie przykładowej tabeli
cursor.execute('''
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
)
''')

# Dodanie przykładowych danych
sample_users = [
    (1, "Jan Kowalski", "jan@example.com"),
    (2, "Anna Nowak", "anna@example.com"),
    (3, "Piotr Wiśniewski", "piotr@example.com")
]

cursor.executemany(
    "INSERT OR REPLACE INTO users (id, name, email) VALUES (?, ?, ?)",
    sample_users
)

conn.commit()
conn.close()

print("Baza danych została zainicjalizowana.")
