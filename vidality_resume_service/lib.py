__author__ = 'marc'

import sys
import re
import os
import sqlite3 as lite
pat1 = '[iI][lL][lL][a-zA-Z0-9:# \r\n/,\+\-\(\)\*:]*[eE][xX][pP]'
pat2 = '[iI][lL][lL][a-zA-Z0-9:# \r\n/,\+\-\(\)\*:]*[eE][dD][uU]'
pat3 = '[iI][lL][lL][a-zA-Z0-9:# \r\n/,\+\-\(\)\*:]*[hH][iI][sS]'

def get_skills_shell(data, cursor):

     data = data.replace('\xe2','')
     if re.search(pat1, data):
         if re.search(pat1, data).group(0):
           skill_set = re.search(pat1, data).group(0)
           spl_skill = skill_set.split(',')
           for s in spl_skill:
              skl = s.replace('(','').replace(')','').replace(',', '').replace('*','').replace(':', '')
              print skl
              q = 'insert into skills (\'name\') values (\'%s\')'%skl
              try:
                  cursor.execute(q)
                  db.commit()
              except lite.IntegrityError:
                  print "Skill %s already exists"%skl
     if re.search(pat2, data):
         if re.search(pat2, data).group(0):
           skill_set = re.search(pat2, data).group(0)
           spl_skill = skill_set.split(',')
           for s in spl_skill:
              skl = s.replace('(','').replace(')','').replace(',', '').replace('*','').replace(':', '')
              print skl
              q = 'insert into skills (\'name\') values (\'%s\')'%skl
              try:
                  cursor.execute(q)
                  db.commit()
              except lite.IntegrityError:
                  print "Skill %s already exists"%skl
     if re.search(pat3, data):
         if re.search(pat3, data).group(0):
           skill_set = re.search(pat3, data).group(0)
           spl_skill = skill_set.split(',')
           for s in spl_skill:
              skl = s.replace('(','').replace(')','').replace(',', '').replace('*','').replace(':', '')
              print skl
              q = 'insert into skills (\'name\') values (\'%s\')'%skl
              try:
                  cursor.execute(q)
                  db.commit()
              except lite.IntegrityError:
                  print "Skill %s already exists"%skl

def get_skills(data):
    skill_list = []
    data = data.replace('\xe2','')
    if re.search(pat1, data):
     if re.search(pat1, data).group(0):
       skill_set = re.search(pat1, data).group(0)
       spl_skill = skill_set.split(',')
       for s in spl_skill:
          skl = s.replace('(','').replace(')','').replace(',', '').replace('*','').replace(':', '')
          print skl
          if skl not in skill_list:
            skill_list.append(skl)

    if re.search(pat2, data):
     if re.search(pat2, data).group(0):
       skill_set = re.search(pat2, data).group(0)
       spl_skill = skill_set.split(',')
       for s in spl_skill:
          skl = s.replace('(','').replace(')','').replace(',', '').replace('*','').replace(':', '')
          print skl
          if skl not in skill_list:
            skill_list.append(skl)
    if re.search(pat3, data):
     if re.search(pat3, data).group(0):
       skill_set = re.search(pat3, data).group(0)
       spl_skill = skill_set.split(',')
       for s in spl_skill:
          skl = s.replace('(','').replace(')','').replace(',', '').replace('*','').replace(':', '')
          print skl
          if skl not in skill_list:
            skill_list.append(skl)
    return skill_list
