#!/usr/bin/python
__author__ = 'amitsolanki'

import MySQLdb
import re
import htmlentitydefs

def cleanuptext(text):
    print repr(text)
    escaped_chars = []
    replace_dict = {"&Agrave;":"A","&Aacute;":"A", "&Acirc;":"A", "&Atilde;":"A", "&Auml;":"A","&Aring;":"A", "&AElig;":"AE",
                    "&Ccedil;":"C", "&Egrave;":"E","&Eacute;":"E", "&Ecirc;":"E","&Euml;":"E", "&Igrave;":"I","&Iacute;":"I",
                    "&Icirc;":"I","&Iuml;":"I", "&ETH;":"D","&Ntilde;":"N", "&Ograve;":"O","&Oacute;":"O", "&Ucirc;":"U",
                    "&Otilde;":"O", "&Ouml;":"O", "&times;":"x", "&Ugrave;":"U", "&Uuml;":"U",
                    "&Yacute;":"Y",  "&THORN;":"P",  "&agrave;":"a", "&aacute;":"a", "&acirc;":"a", "&atilde;":"a",
                    "&auml;":"a", "&aring;":"a", "&aelig;":"ae", "&ccedil;":"c", "&egrave;":"e", "&eacute;":"e", "&ecirc;":"e",
                    "&euml;":"e", "&igrave;":"i", "&iacute;":"i", "&icirc;":"i", "&iuml;":"i", "&eth;":"o", "&ntilde;":"n",
                    "&ograve;":"o", "&oacute;":"o", "&ocirc;":"o", "&otilde;":"o", "&ouml;":"o", "&divide;":"/",
                    "&oslash;":"o", "&ugrave;":"u", "&uacute;":"u", "&ucirc;":"u", "&uuml;":"u", "&yacute;":"y",
                    "&thorn;":"p", "&yuml;":"y", "\xc3\x80":"A", "\xc3\x81":"A", "\xc3\x82":"A", "\xc3\x83":"A", "\xc3\x84":"A", "\xc3\x85":"A",
                    "\xc3\x86":"AE", "\xc3\x87":"C", "\xc3\x88":"E", "\xc3\x89":"E", "\xc3\x8a":"E", "\xc3\x8b":"E", "\xc3\x8c":"I", "\xc3\x8d":"I",
                    "\xc3\x8e":"I", "\xc3\x8f":"I", "\xc3\x91":"N", "\xc3\x92":"O", "\xc3\x93":"O", "\xc3\x94":"O", "\xc3\x95":"O", "\xc3\x96":"O",
                    "\xc3\x97":"x", "\xc3\x98":"O", "\xc3\x99":"U", "\xc3\x9a":"U", "\xc3\x9b":"U", "\xc3\x9c":"U", "\xc3\x9d":"Y", "\xc3\x9f":"S",
                    "\xc3\xa0":"a", "\xc3\xa1":"a", "\xc3\xa2":"a", "\xc3\xa3":"a", "\xc3\xa4":"a", "\xc3\xa5":"a", "\xc3\xa6":"ae", "\xc3\xa7":"c",
                    "\xc3\xa8":"e", "\xc3\xa9":"e", "\xc3\xaa":"e", "\xc3\xab":"e", "\xc3\xac":"i", "\xc3\xad":"i", "\xc3\xae":"i", "\xc3\xaf":"i",
                    "\xc3\xb1":"n", "\xc3\xb2":"o", "\xc3\xb3":"o", "\xc3\xb4":"o", "\xc3\xb5":"o", "\xc3\xb6":"o", "\xc3\xb7":"/", "\xc3\xb8":"o",
                    "\xc3\xb9":"u", "\xc3\xba":"u", "\xc3\xbb":"u", "\xc3\xbc":"u", "\xc3\xbd":"y", "\xc3\xbf":"y", "&#xC0;":"A", "&#xC1;":"A", "&#xC2;":"A",
                    "&#xC3;":"A", "&#xC4;":"A", "&#xC5;":"A", "&#xC6;":"AE", "&#xC7;":"C", "&#xC8;":"E", "&#xC9;":"E", "&#xCA;":"E", "&#xCB;":"E", "&#xCC;":"I",
                    "&#xCD;":"I", "&#xCE;":"I", "&#xCF;":"I", "&#xD1;":"N", "&#xD2;":"O", "&#xD3;":"O", "&#xD4;":"O", "&#xD5;":"O", "&#xD6;":"O", "&#xD7;":"x",
                    "&#xD8;":"O", "&#xD9;":"U", "&#xDA;":"U", "&#xDB;":"U", "&#xDC;":"U", "&#xDD;":"Y", "&#xDF;":"S", "&#xE0;":"a", "&#xE1;":"a", "&#xE2;":"a",
                    "&#xE3;":"a", "&#xE4;":"a", "&#xE5;":"a", "&#xE6;":"ae", "&#xE7;":"c", "&#xE8;":"e", "&#xE9;":"e", "&#xEA;":"e", "&#xEB;":"e", "&#xEC;":"i",
                    "&#xED;":"i", "&#xEE;":"i", "&#xEF;":"i", "&#xF1;":"n", "&#xF2;":"o", "&#xF3;":"o", "&#xF4;":"o", "&#xF5;":"o", "&#xF6;":"o", "&#xF7;":"/",
                    "&#xF8;":"o", "&#xF9;":"u", "&#xFA;":"u", "&#xFB;":"u", "&#xFC;":"u", "&#xFD;":"y", "&#xFF;":"y"}

    for c in text:
        if (ord(c) < 32) or (ord(c) > 126):
            try:
                c = '&{};'.format(htmlentitydefs.codepoint2name[ord(c)])
            except:
                c = c
            c.replace("&iexcl;","")
            for k,v in replace_dict.iteritems():
                c = c.replace(k, v)



        escaped_chars.append(c)



    return ''.join(escaped_chars)

def dbconnection(config):
    dbserver = config['server']
    dbuser = config['user']
    dbpass = config['pass']
    dbdatabase = config['database']
    try:
        db = MySQLdb.connect(dbserver, dbuser, dbpass, dbdatabase)
        #print "Database connection successful"
        return db
    except Exception as e:
        print "NOT ABLE to connect to Database"
        print e
        exit(100)


def add_city(city_name, state_id, db, logger):
    cursor = db.cursor()
    logger.info("Adding City Name : %s\n" % city_name)
    sql = "insert into city(name,state_id) values(%s,%s) " % ( city_name, int(state_id))
    logger.info(sql)
    try:

        cursor.execute("insert into city(name,state_id) values(%s,%s) " , ( city_name, state_id))
        city_id = cursor.lastrowid
    except Exception as inst:
        logger.warning(sql)
        logger.warning(inst)
        city_id = 0

    db.commit()
    #globals.city_added += 1

    cursor.close()
    return(city_id)

def add_state(state_name, country_id, db, logger):
    cursor = db.cursor()
    logger.info("Adding State Name : %s\n" % state_name)
    try:
        sql = "insert into state(name,country_id) values('%s',%s) " % ( state_name, int(country_id))
        cursor.execute(sql)
        db.commit()
        state_id = cursor.lastrowid
    except Exception as inst:
        logger.warning(sql)
        logger.warning("State cannot be added.")
        logger.warning(inst)
        state_id = 0

    cursor.close()
    return(state_id)


def add_country(country_name, db, logger):
    cursor = db.cursor()
    logger.info("Adding Country Name : %s\n" % country_name)
    try:
        sql = "insert into country(name) values(%s) " % country_name
        cursor.execute(sql)
        db.commit()
        country_id = cursor.lastrowid
    except Exception as inst:
        logger.warning(sql)
        logger.warning("State cannot be added.")
        logger.warning(inst)
        country_id  = 0
    cursor.close()
    #globals.country_added += 1
    return (country_id)



def add_links_2_process(link_list, config, logger):
    db = dbconnection(config)
    cursor = db.cursor()
    for profile in link_list:
        #print link_list

        plink = db.escape_string(profile['href']).replace("?trk=pub-pbmap","")

        logger.info(plink)
        sql = "select * from %s where link = '%s'" % ( config['link2process'], plink)
        cursor.execute(sql)
        if cursor.rowcount == 0:
            insertpart = "insert into %s (link) values ('%s')" % ( config['link2process'], plink)
            cursor.execute(insertpart)
            db.commit()
    cursor.close()
    db.close()
    return


class person:
    def __init__(self, name, city_id, url_linkedin, url_twitter, url_personal, url_future1, url_future2, url_future3, url_future4, config):
        self.id = 0
        try:
            self.name = MySQLdb.escape_string(name.encode('utf-8'))
        except:
            self.name = cleanuptext(name)
        self.email = ""
        self.phone = ""
        self.city_id = city_id
        self.zip = ""
        self.url_linkedin = MySQLdb.escape_string(url_linkedin)
        self.url_facebook = ""
        try:
            self.url_twitter = MySQLdb.escape_string(url_twitter.encode('utf-8'))
        except:
            self.url_twitter = ""
        self.url_github = ""
        self.url_quora = ""
        self.url_stakeof = ""
        self.url_angelslist = ""
        try:
            self.url_person = MySQLdb.escape_string(url_personal.encode('utf-8'))
        except:
            self.url_person = ""

        self.url_resume = ""
        try:
            self.url_future1 = MySQLdb.escape_string(url_future1.encode('utf-8'))
        except:
            self.url_future1 = ""
        try:
            self.url_future2 = MySQLdb.escape_string(url_future2.encode('utf-8'))
        except:
            self.url_future2 = ""
        try:
            self.url_future3 = MySQLdb.escape_string(url_future3.encode('utf-8'))
        except:
            self.url_future3 = ""
        try:
            self.url_future4 = MySQLdb.escape_string(url_future4.encode('utf-8'))
        except:
            self.url_future4 = ""
        self.url_future5 = ""
        self.url_future6 = ""
        self.config = config
        self.is_exist = False

    def save(self,config,logger):
        # Check if this url is already exists on not.
        # If exists then return 0 which means this url is already processed.
        # If not then insert into person table and return person_id
        #   For all blank value we need to store null
        #   All strings will be encoded fro mysql insert
        checkurlsql="select id from person where url_linkedin = '%s'" % self.url_linkedin
        print checkurlsql
        db = dbconnection(config)

        cursor = db.cursor()

        try:
            cursor.execute(checkurlsql)
        except Exception as e:
            logger.critical("Some error occured on database. URL need to be reprocessed. \n%s" % e )
            logger.critical(self.url_linkedin)
            exit(100)

        if cursor.rowcount == 0:
            #print "No duplicate"

            #print insert_sql
            try:
                cursor.execute("insert into person (name, city_id, url_linkedin, url_twitter, url_person, url_future1, " \
                           "url_future2,  url_future3, url_future4 ) values( %s, %s, %s, %s, %s , %s, %s, %s, %s)", (self.name, int(self.city_id), self.url_linkedin,
                                                                                                      (self.url_twitter if self.url_twitter else None),
                                                                                                      (self.url_person if self.url_person else None),
                                                                                                      (self.url_future1 if self.url_future1 else None),
                                                                                                      (self.url_future2 if self.url_future2 else None),
                                                                                                      (self.url_future3 if self.url_future3 else None),
                                                                                                      (self.url_future4 if self.url_future4 else None)))
                db.commit()
                ##globals.profile_processed += 1
                self.id = cursor.lastrowid
                cursor.execute("INSERT INTO data_table (email, profile_url, created_date, person_id) "
                               "values (%s, %s, now(), %s)",(config['email'],self.url_linkedin,self.id))
                db.commit()

            except Exception as inst:
                logger.critical("%s Failed to insert person" % self.url_linkedin)
                logger.critical(inst)

#            linkrow = cursor.fetchone()
#            link = linkrow[0]
#            print link
        else:
            row = cursor.fetchone()
            self.id = row[0]
            self.is_exist = True
            logger.warning("Duplicate record found")

        deletesql= "delete from %s where link = '%s'" % (config['link2process'], self.url_linkedin)
        cursor.execute(deletesql)
        db.commit()


#    def forcesave(self):
        # means if record exists then update everywhere.
#        checkurlsql="select person_id from person where url_linkedin = '%s'" % self.url_linkedin
#        print checkurlsql

class location:


    def __init__(self, location_text,config,logger):
        location_list= location_text.strip('\n').split(',')
        self.city_id = 0
        self.state_id = 0
        self.country_id = 0
        db = dbconnection(config)

        if len(location_list) == 3:
            self.city_name = MySQLdb.escape_string(location_list[0].encode('utf-8'))
            self.state_name = MySQLdb.escape_string(location_list[1].encode('utf-8'))
            self.country_name = MySQLdb.escape_string(location_list[2].encode('utf-8'))
        elif len(location_list) == 2:
            self.city_name = MySQLdb.escape_string(location_list[0].encode('utf-8'))
            self.state_name = MySQLdb.escape_string(location_list[1].encode('utf-8'))
            self.country_name = MySQLdb.escape_string(location_list[1].encode('utf-8'))

        elif len(location_list) == 1:
            self.city_name = MySQLdb.escape_string(location_list[0].encode('utf-8'))
            self.state_name = MySQLdb.escape_string(location_list[0].encode('utf-8'))
            self.country_name = MySQLdb.escape_string(location_list[0].encode('utf-8'))
        else:
            return(0)

        # Cleaning City State and Country Name

        self.city_name = re.sub(r'^Greater ', r'', self.city_name).rstrip('\n').strip()
        self.city_name = re.sub(r' Area$', r'', self.city_name).rstrip('\n').strip()
        self.city_name = re.sub(r'\(.*?\)', r'', self.city_name).rstrip('\n').strip()

        self.state_name = re.sub(r'^Greater ', r'', self.state_name).rstrip('\n').strip()
        self.state_name = re.sub(r' Area$', r'', self.state_name).rstrip('\n').strip()
        self.state_name = re.sub(r'\([^)]*\)', r'', self.state_name).rstrip('\n').strip()

        self.country_name = re.sub(r'^Greater ', r'', self.country_name).rstrip('\n').strip()
        self.country_name = re.sub(r' Area$', r'', self.country_name).rstrip('\n').strip()
        self.country_name = re.sub(r'\([^)]*\)', r'', self.country_name).rstrip('\n').strip()

        if self.city_name == self.country_name:
            country_check_sql="select 'country' as place, id from country where ( name = '%s' or alias = '%s' )" \
                            " union select 'state' as place, id from state where ( name = '%s' or alias = '%s' )" \
                            " union select 'city' as place, id from city where ( name = '%s' or alias = '%s' )" % (self.city_name, self.city_name,
                                                                                                                   self.city_name, self.city_name,
                                                                                                                   self.city_name, self.city_name)

            print country_check_sql
            cursor = db.cursor()
            cursor.execute(country_check_sql)
            if cursor.rowcount != 0:

                rows = cursor.fetchall()
                print rows
                for row in rows:
                    location=row[0]
                    print location
                    location_id=row[1]

                print "%s - %s " % (location, location_id)
                if location == "country":
                    print "Found Country as country so going to create entry in State and City\n"
                    self.country_id = location_id

                    self.state_id = add_state(self.country_name, self.country_id, db, logger)
                    if self.state_id == 0:
                        self.city_id = 0
                    else:
                        self.city_id = add_city(self.country_name, self.state_id, db, logger)
                elif location == "state":
                    print "Found Country as State so going to create entry in City\n"

                    self.state_id = location_id
                    self.city_id = add_city(self.country_name, self.state_id, db, logger)
                    stateCountrySQL = "select country_id from state s where s.id=%d " % self.state_id
                    cursor.execute(stateCountrySQL)
                    row123=cursor.fetchone()
                    self.country_id = row123[0]
                elif location == "city":
                    print "Found Country as city.\n"
                    self.city_id = location_id
                    stateCountrySQL = " select country_id, state_id " \
                                      " from state s, city ci " \
                                      " where ci.id=%d " \
                                      " and s.id = ci.state_id" % self.city_id
                    print stateCountrySQL
                    cursor.execute(stateCountrySQL)
                    row123=cursor.fetchone()
                    self.country_id = row123[0]
                    self.state_id = row123[1]
            else:
                print "This record doesn't exists in our database so going to create one in Country, State and City table.\n"
                self.country_id= add_country(self.country_name, db, logger)
                if self.country_id == 0:
                    self.state_id = 0
                    self.city_id = 0
                else:
                    self.state_id= add_state(self.country_name, self.country_id, db, logger)
                    if self.state_id == 0:
                        self.city_id = 0
                    else:
                        self.city_id= add_city(self.country_name, self.state_id, db, logger)

        else:

            if self.country_name == self.state_name:
                country_check_sql="select 'country' as place, id from country " \
                                "where ( name ='%s' or " \
                                " alias ='%s' or " \
                                " local_name ='%s') " \
                                " union " \
                                " select 'state' as place, id from state " \
                                " where ( name ='%s' or alias ='%s' ) " % (self.country_name, self.country_name,
                                                                          self.country_name, self.country_name, self.country_name)

            else:
                country_check_sql=" select 'country' as place, id from country " \
                                " where ( name ='%s' or " \
                                " alias ='%s' or " \
                                " local_name ='%s') " % (self.country_name, self.country_name, self.country_name )

            print country_check_sql
            db = dbconnection(config)
            cursor = db.cursor()
            cursor.execute(country_check_sql)
            if cursor.rowcount != 0:
                rows = cursor.fetchall()
                for row in rows:
                    location=row[0]
                    location_id=row[1]
                    print "%s - %s " % (location, location_id)

                if location == "country":
                    print "country name is Country\n"
                    self.country_id = location_id
                    if self.state_name != self.country_name:
                        sql="select id from state where country_id = %d and name ='%s'" % (self.country_id, self.state_name)
                        print sql
                        staterowrst= cursor.execute(sql)

                        if cursor.rowcount == 0:
                            self.state_id = add_state (self.state_name, self.country_id, db, logger)
                        else:

                            staterow=cursor.fetchone()
                            self.state_id=staterow[0]

                    else:
                        self.state_id= add_state(self.state_name, self.country_id, db, logger)

                elif location == "state":

                    print "country name is State\n"
                    self.state_id= location_id
                    sql=" select country_id from state where id =%d" % self.state_id

                    countryrowrst= cursor.execute(sql)

                    countryrow=cursor.fetchone()
                    self.country_id=countryrow[0]
                    print self.country_id




            else:
                print "Cannot find in country or state table. Going to add one now.\n"
                self.country_id= add_country(self.country_name, db, logger)

                if self.state_name != self.country_name:
                    sql="select id from state where name ='%s'" % self.state_name

                    staterowrst= cursor.execute(sql)

                    if staterowrst.rowcount == 0:
                        self.state_id= add_state(self.state_name, self.country_id, db, logger);
                    else:
                        staterow=staterowrst.fetchone()
                        self.state_id=staterow[0]

                else:
                    self.state_id= add_state (self.country_name, self.country_id, db, logger)

            if self.state_id == 0:
                self.city_id = 0
            else:

                print "Now checking City.\n";

                cityCheckSQL="select 'state' as place, id from state " \
                             "where ( name ='%s' or alias ='%s' ) and country_id = %d " \
                             " union " \
                             " select 'city' as place, id from city " \
                             " where ( name ='%s' or alias ='%s' ) and state_id = %d " % (self.city_name, self.city_name, self.country_id,
                                                                                        self.city_name, self.city_name, self.state_id)

                print "City SQL : %s\n" % cityCheckSQL

                cursor.execute(cityCheckSQL)

                cityNo = cursor.rowcount

                print "City No : %d \n" % cityNo


                if cityNo != 0 and self.city_id == 0:
                    rows = cursor.fetchall()
                    for row4 in rows:

                        location2 = row4[0]
                        location2_id = row4[1]
                    print location2
                    print location2_id

                    if location2 == "state":
                        self.state_id = location2_id
                        sql = "select country_id from state where id = %d" % self.state_id

                        cursor.execute(sql)

                        countryrow=cursor.fetchall()

                        self.country_id = countryrow[0]
                        self.city_id= add_city(self.city_name,self.state_id, db, logger)
                    elif location2 == "city":
                        self.city_id = location2_id
                        stateCountrySQL=" select country_id, state_id " \
                                        " from state s, city ci " \
                                        " where ci.id=%d " \
                                        " and s.id = ci.state_id " % self.city_id


                        print stateCountrySQL
                        cursor.execute(stateCountrySQL)
                        statecountryrow=cursor.fetchone()

                        self.state_id = statecountryrow[1]
                        self.country_id = statecountryrow[0]
                else:
                    print "This city doesn't exists. Going to insert one.\n"
                    self.city_id= add_city(self.city_name, self.state_id, db, logger)


        #print self.city_name + " - " + str(self.city_id)
        #print self.state_name + " - " + str(self.state_id)
        #print self.country_name + " - " + str(self.country_id)

        cursor.close()
        db.close()


class school:

    def __init__(self, pid, schoolname, degree, majors, start, end):
        self.person_id = pid
        try:
            self.name = MySQLdb.escape_string(( schoolname.encode('utf-8') if schoolname else None))
        except:
            self.name = cleanuptext(schoolname)

        try:
            self.degree = ( degree if degree  else None)

        except:
            self.degree = cleanuptext(degree)
        try:
            self.majors = (majors if majors else None)
        except:
            self.majors = cleanuptext(majors)


        self.start = (start if start else None)
        self.end = (end if end else None)

        if self.majors:
            try:
                self.majors = MySQLdb.escape_string(majors.encode('utf-8'))
            except:
                self.majors = ""
        if self.degree:
            try:
                self.degree = MySQLdb.escape_string(degree.encode('utf-8'))
            except:
                self.degree = ""

        if self.end:
            self.end = MySQLdb.escape_string(end)
        if self.start:
            self.start = MySQLdb.escape_string(start)

    def save(self,config, logger):

        #1. Check if School Exists or not
        #a. If Exists
        #       then get a school Id
        #       insert row into schoolAttended Table.
        #b. If Doesn't Exists
        #       then Insert a school record
        #       Get a ID
        #       insert row into schoolAttended Table.
        school_id = 0
        db = dbconnection(config)
        cursor = db.cursor()
        #school_check_sql = "select * from school where name = %s or alias = %s" % (self.schoolname, self.schoolname)
        cursor.execute( "select * from school where name = %s or alias = %s", (self.name, self.name))
        insert_school_sql = ""

        if cursor.rowcount != 0:
            row = cursor.fetchone()
            school_id = row[0]
        else:
            insert_school_sql = "insert into school (name, city_id, alias) values ('%s', 0, '%s')" % (self.name, self.name)
            cursor.execute("insert into school (name, city_id, alias) values (%s, 0, %s)", (self.name, self.name))
            ##globals.school_added += 1
            school_id = cursor.lastrowid

        #print school_id

        if school_id != 0:
            '''
            insert_school_attend_sql = "INSERT INTO schoolattended (person_id, school_id, degree, major, minor, fmDate, toDate) " \
                           "VALUES (%s, '%s', '%s', '%s', '%s', '%s')" % (self.person_id, school_id,
                                                                (self.degree if self.degree else None),
                                                                (self.majors if self.majors else None),
                                                                 (self.start if self.start else None),
                                                                  (self.end if self.end else None) )
            '''
            #print insert_school_attend_sql

            cursor.execute("""INSERT INTO schoolattended (person_id, school_id, degree, major, fmDate, toDate)
                            VALUES (%s, %s, %s, %s, %s, %s)""", (self.person_id, school_id,
                                                               (self.degree if self.degree else None),
                                                               (self.majors if self.majors else None),
                                                               (self.start if self.start else None),
                                                               (self.end if self.end else None)))

            db.commit()
        else:

            logger.critical("No School Id Found and Cannot insert one. School name %s " % self.name)
            logger.critical("%s" % insert_school_sql)
        db.close()


class skill:

    def __init__(self, pid, skill_name, endorsements):
        self.person_id = pid
        try:
            self.name = skill_name.encode('ascii', 'ignore')
        except:
            self.name = cleanuptext(skill_name.encode('ascii', 'ignore'))

        self.level = endorsements

    def save(self, config, logger):
        skill_id = 0
        db = dbconnection(config)
        cursor = db.cursor()

        cursor.execute( "select * from skill where name = %s or alias = %s", (self.name, self.name))

        if cursor.rowcount != 0:
            row = cursor.fetchone()
            skill_id = row[0]
        else:
            cursor.execute("insert into skill (name, alias) values (%s, %s)", (self.name, self.name))
            skill_id = cursor.lastrowid
            ##globals.skill_added += 1
        if skill_id != 0:

            cursor.execute("select * from ownskillset where person_id = %s and skill_id = %s", (self.person_id, skill_id))
            self.level = (self.level if self.level else 0)
            if cursor.rowcount == 0:
                cursor.execute("""INSERT INTO ownskillset (person_id, skill_id, level)
                            VALUES (%s, %s, %s)""", (self.person_id, skill_id,self.level))
                db.commit()
            else:
                logger.warning("This skill is already added for the person.")
                logger.warning("%s - %s (%s)" % (self.person_id, self.name, skill_id))
        else:
            logger.critical("No skill Id Found and Cannot insert one. skill name %s " % self.name)

        db.close()



class images:
    def __init__(self, pid, imagepath, source):
        self.person_id = pid
        self.source_id = source
        self.image_path = imagepath

    def save(self, config, logger):
        db = dbconnection(config)
        cursor = db.cursor()

        cursor.execute("select * from images where person_id = %s and source_id = %s", (self.person_id, self.source_id))
        if cursor.rowcount != 0:
            row = cursor.fetchone()
            image_id = row[0]
            print "Updating image"
            cursor.execute("update images set path = %s where id = %s", (self.image_path, image_id))

        else:
            print "Inserting image"
            cursor.execute("insert into images (person_id, source_id, path) values (%s, %s, %s)", (self.person_id, self.source_id, self.image_path))
            ##globals.images_added += 1

        db.commit()
        cursor.close()
        db.close()

class experiance:
    def __init__(self, pid, company, title, startTime, endTime):
        self.person_id = pid

        try:
            self.company = MySQLdb.escape_string(company.encode('utf-8'))
        except:
            self.company = cleanuptext(company)

        try:
            self.title = MySQLdb.escape_string(title.encode('utf-8'))
        except:
            self.title = cleanuptext(title)

        self.start = startTime
        self.end = endTime

    def save(self, config, logger):
        company_id = 0
        db = dbconnection(config)
        cursor = db.cursor()
        company_check="select * from company where name = '%s' " % (self.company)
        cursor.execute(company_check)

        if cursor.rowcount != 0:
            row = cursor.fetchone()
            company_id = row[0]
        else:
            insert_company = "insert into company (name, city_id) values ('%s',0)" % (self.company)
            cursor.execute(insert_company)
            db.commit()
            company_id = cursor.lastrowid


        if company_id != 0:

            cursor.execute( """select * from companyworkedfor where person_id = %s
                            and company_id = %s
                            and jobTitle = %s
                            and fmDate = %s
                            and toDate = %s""", (self.person_id, company_id, self.title, self.start, self.end))
            #print "exp row count %s" % cursor.rowcount
            if cursor.rowcount == 0:
                #print """INSERT INTO companyworkedfor (person_id, jobTitle, company_id, fmDate, toDate)
                #            VALUES (%s, %s, %s, %s, %s)""" % (self.person_id, self.title, company_id,self.start, self.end)

                cursor.execute("""INSERT INTO companyworkedfor (person_id, jobTitle, company_id, fmDate, toDate)
                            VALUES (%s, %s, %s, %s, %s)""", (self.person_id, self.title, company_id,self.start, self.end))
                db.commit()
                ##globals.company_added += 1
            else:
                print "Duplicate Record."
                #print "%s - %s (%s)" % (self.person_id, self.name, company_id)
        else:
            print "No School Id Found and Cannot insert one."

        db.close()


class extraInfo:

    def __init__(self, pid, title, industry, summary, hasmoreskills, languages, interests, connections, recommendations):
        self.person_id = pid
        try:
            self.title = (title.encode('utf-8') if title else None)
        except:
            self.title = cleanuptext(title)
        try:
            self.industry = (industry.encode('utf-8') if industry else None)
        except:
            self.industry = cleanuptext(industry)
        try:
            self.summary = (summary.encode('utf-8') if summary else None)
        except:
            self.summary = cleanuptext(summary)

        self.hasmoreskills = (hasmoreskills.encode('utf-8') if hasmoreskills else None)
        try:
            self.languages = (languages.encode('utf-8') if languages else None)
        except:
            self.languages = cleanuptext(languages)
        try:
            self.interests = (interests.encode('utf-8') if interests else None)
        except:
            self.interests = cleanuptext(interests)
        self.connections = ( connections if connections else None)
        self.recommendations = ( recommendations if recommendations else None)


    def save(self, config, logger):
        db = dbconnection(config)
        cursor = db.cursor()
        logger.info("Checking Extra")
        check_sql = "select * from extralinkedininfo where person_id = %s" % self.person_id
        cursor.execute(check_sql)
        if cursor.rowcount != 0:
            row = cursor.fetchone()
            extra_id = row[0]
            logger.info("Updating Extra")
            cursor.execute("""update extralinkedininfo
            set title = %s,
                industry = %s,
                summary = %s,
                hasmoreskills = %s,
                languages = %s,
                interests = %s,
                connections = %s,
                recommendations = %s
            where id = %s""", (self.title,
                               self.industry,
                               self.summary,
                               self.hasmoreskills,
                               self.languages,
                               self.interests,
                               self.connections,
                               self.recommendations,
                               extra_id))

        else:
            logger.info("Inserting Extra")
            try:
                cursor.execute("""insert into extralinkedininfo (person_id, title, industry, summary, hasmoreskills, languages,
                interests, connections, recommendations) values (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                           (self.person_id, self.title, self.industry, self.summary, self.hasmoreskills,
                            self.languages, self.interests, self.connections, self.recommendations))
            except Exception as inst:
                logger.critical(inst)


        db.commit()
        cursor.close()
        db.close()
