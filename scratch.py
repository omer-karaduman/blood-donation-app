import psycopg2
conn = psycopg2.connect('postgresql://blood_donation_db_o17w_user:1chpoC27lJRBk1gChEcdrS3N9eGF3A7s@dpg-d7b07rffte5s73d1bns0-a.frankfurt-postgres.render.com/blood_donation_db_o17w')
cur = conn.cursor()
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
tables = cur.fetchall()
print('Tables:', tables)
cur.close()
conn.close()
