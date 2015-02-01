
import re
import os
from lib import get_skills_shell
import sqlite3 as lite
db = lite.connect('test.db')

cursor = db.cursor()
for file in os.listdir('.'):
  if re.search('\.txt$', file):
     f = open(file, 'r')
     data = f.read()
     get_skills_shell(data, cursor)