#!/usr/bin/python
__author__ = 'amitsolanki'
import ConfigParser
import os
import datetime
import urllib
import re
from datetime import date, time
import time
import MySQLdb
from bs4 import BeautifulSoup

from dbclasses import person, location, school, skill, experiance, images, extraInfo, add_links_2_process, dbconnection


def BeautifulSoupFunction(html_source, url_linkedin, config, logger):
    #print html_source
    logger.info("Received request to process link %s" % url_linkedin)

    month_dict = {'Jan':'01','Feb':'02','Mar':'03','Apr':'04','May':'05','Jun':'06',
                      'Jul':'07','Aug':'08','Sep':'09','Oct':'10','Nov':'11','Dec':'12',
                      'January':'01','February':'02','March':'03','April':'04', 'June':'06',
                      'July':'07','August':'08','September':'09','October':'10','November':'11','December':'12'}

    soup = BeautifulSoup(html_source, 'html.parser')
    currenttitle = ""
    currentindustry = ""
    try:
        profilename = soup.title.text.replace('| LinkedIn', '').strip()
    except:
        print_str = "This profile cannot be process because cannot figure out profile name."
        logger.critical(print_str)
        db = dbconnection(config)
        cursor = db.cursor()
        time.sleep(13)
        insert_failed = "insert into failed2process (link) values ('%s')" % url_linkedin
        cursor.execute(insert_failed)
        db.commit()
        cursor.close()
        db.close()
        print print_str
        return (currenttitle,currentindustry)


    try:
        locationtag = soup.find_all('span',{'class':'locality'})[0]
    except:
        locationtag = ""
        print_str = "This profile cannot be process because You and this LinkedIn user don't know anyone in common"
        logger.critical(print_str)
        db = dbconnection(config)
        cursor = db.cursor()
        time.sleep(13)
        insert_failed = "insert into failed2process (link) values ('%s')" % url_linkedin
        cursor.execute(insert_failed)
        db.commit()
        cursor.close()
        db.close()
        print print_str
        return (currenttitle,currentindustry)

    #print profilename
    if profilename:
        logger.info("Profile name found : %s" , profilename)
    else:
        logger.warning("Profile name NOT found")

    profiledesc=""
    for hit in soup.findAll(attrs={'class' : 'summary'}):
        profiledesc = hit.text
        break

    public_url = soup.find_all('span',{'class':'view-public-profile'})

    try:
        url_linkedin = public_url[0].text
        logger.info("Profile public url found")
        try:
            print MySQLdb.escape_string(url_linkedin)
        except:
            print  "Public url has special characters... Going to Skip"
            logger.info( "Public url has special characters... Going to Skip")
            return (currenttitle,currentindustry)
    except:
        try:
            public_url = soup.find_all('a',{'class':'view-public-profile'})
            url_linkedin = public_url[0].text
            logger.info("Profile public url found")
            try:
                print MySQLdb.escape_string(url_linkedin)
            except:
                print  "Public url has special characters... Going to Skip"
                logger.info( "Public url has special characters... Going to Skip")
                return (currenttitle,currentindustry)
        except:
            logger.info( "No public url found.")
            print_str = "This profile cannot be process because You and this LinkedIn user don't know anyone in common"
            logger.critical(print_str)
            db = dbconnection(config)
            cursor = db.cursor()
            insert_failed = "insert into failed2process (link) values ('%s')" % url_linkedin
            cursor.execute(insert_failed)
            db.commit()
            cursor.close()
            db.close()
            return (currenttitle,currentindustry)


    try:
        total_connect = soup.find_all('div',{'class':'member-connections'})[0].find_all('strong')[0].text.strip('+')
    except:
        total_connect = 0

    logger.info("Total Connections - %s " % total_connect)
    try:
        total_recommendation = soup.find_all('div',{'class':'profile-endorsements'})[0]['data-total-recommendations']
    except:
        total_recommendation = 0

    logger.info("Total Recommendations - %s " % total_recommendation)

    # Check if newer version
    alsoViewed = soup.find_all('a',{'class':'browse-map-photo'})

    # Check if older version
    if not alsoViewed:
        alsoViewed = soup.find_all('li',{'class':'with-photo'})
        alsoViewed = soup.find_all(lambda tag: tag.name == 'a' and tag.findParent('strong'))

    # Check Similar profile/Older version doesnt have it.
    similarprofile = soup.find_all('a',{'class':'discovery-photo'})

    #logger.info("Adding Also Viewed Profile to links2 process")
    #print locationtag
    try:
        locationText = locationtag.find_all('a')[0].text
    except:
#        print locationtag
        locationText = locationtag.text

    locationObj = location(locationText, config, logger)

    logger.info("Location : %s" % locationText)

    #
    # Using this we can control if we should allowed view_similar profile to be inserted or not.
    #
    db = dbconnection(config)
    cursor = db.cursor()
    view_similar_insert_check = "select * from settings where title='view_similar_insert'"
    view_similar_insert = 0
    try:
        cursor.execute(view_similar_insert_check)
        row = cursor.fetchone()
        view_similar_insert = int(row[1])
        db.commit()
        cursor.close()
        db.close()
        if locationObj.state_id == 5 and view_similar_insert == 1:
            add_links_2_process(alsoViewed, config, logger)
            add_links_2_process(similarprofile, config, logger)

    except:
        view_similar_insert = 0



    try:
        currenttitletag = soup.find_all('div',{'id':'headline'})[0]
        currenttitlecomp = currenttitletag.find_all('p')[0].text
        currenttitle = currenttitlecomp.split(' at ')[0].strip()
        try:
            currentcompany = currenttitlecomp.split(' at ')[1].strip()
        except:
            currentcompany = ""

    except:
        try:

            currenttitletag = soup.find_all('p',{'class':'headline-title title'})[0]
            currenttitlecomp = currenttitletag
            #print currenttitlecomp
            currenttitle = currenttitlecomp.text.split(' at ')[0].strip()
        #   print currenttitle
            try:
                currentcompany = currenttitlecomp.text.split(' at ')[1].strip()
            except:
                currentcompany = ""
        except:
            currentcompany = ""
            currenttitle = ""

    logger.info("Current Title : %s " % currenttitle)
    logger.info("Current Company : %s " % currentcompany)

    try:
        currentindustrytag= soup.find_all('dd',{'class':'industry'})[0]
    except:
        currentindustrytag= ""

    try:
        currentindustry = currentindustrytag.find_all('a')[0].text
    except:
        try:
            currentindustry = currentindustrytag.text
        except:
            currentindustry = ""

    logger.info("Current Industry : %s " % currentindustry)

#   print "==========================================================================="
#==================================================================================================================
#   Contact Info

    logger.info("Checking Websites=================================================================")
    twitterviewtag = soup.find_all('div',{'id' : 'twitter-view'})
    url_twitter = ""
    twittername = ""
    for twitterview in twitterviewtag:
        url_twitter = urllib.unquote(twitterview.find_all('a')[0]['href']).replace('/redir/redirect?url=','')
        twittername = twitterview.find_all('a')[0].text


    websitetags = soup.find_all('div',{'id' : 'website-view'})
    url_future1 = ""
    url_future2 = ""
    url_future3 = ""
    url_future4 = ""
    url_personal =""
    for websites in websitetags :
        for website in websites.find_all('a'):
            webtitle = website.text
            weburl = urllib.unquote(website['href']).replace('/redir/redirect?url=','')

            match = re.search(r"&urlhash=", weburl)
            index=match.start(0)
            weburl = weburl[:index]
#            print webtitle
            match = re.search(r"[personal|Personal]", webtitle)
            #index = match.start(0)
            #print index
            if url_personal == "":
                url_personal = weburl
            elif url_future1 == "":
                url_future1 = weburl
            elif url_future2 == "":
                url_future2 = weburl
            elif url_future3 == "":
                url_future3 = weburl
            elif url_future4 == "":
                url_future4 = weburl

            #print weburl
    #    print "----"


#    match = re.search(r"&urlhash=", url_twitter)
#    index=match.start(0)
#    url_twitter = url_twitter[:index]
#    print twittername
#    print url_twitter
#    print url_personal
#    print url_future1
#    print url_future2
#    print url_future3
#    print url_future4

#==================================================================================================================
#   <div id="languages-view">
    logger.info("Checking Languages=================================================================")
    language_list=" "
    for languages in soup.find_all('div',{'id':'languages-view'}):
        for language in languages.find_all('h4'):
            language_list += language.text +", "

    try:
        language_list = language_list.strip()[:-1]
    except:
        language_list = ""

    logger.info(language_list)
#   print "==========================================================================="

#==================================================================================================================
#   Interests
    interest_list = ""
    logger.info("Checking Interests=================================================================")
    all_interest_tags = soup.find_all('ul',{'class':'interests-listing'})
    if all_interest_tags:
        for interests in all_interest_tags:
            for interest in interests.find_all('a'):
                interest_list += interest.text + ", "
        try:
            interest_list = interest_list.strip()[:-1]
        except:
            interest_list = ""
    else:
        all_interest_tags = soup.find_all('dd',{'class':'interests','id':'interests'})
        try:
            interest_list = all_interest_tags[0].find_all('p')[0].text
        except:
            interest_list = ""

    logger.info(interest_list)
#    print "==========================================================================="

#==================================================================================================================
# Profile-photo
    #print soup.find_all('div',{'class':'profile-picture'})[0].find(itemprop="image")
    logger.info("Checking Photos=================================================================")
    try:
        imagepath = [x['src'] for x in soup.find_all('div',{'class':'profile-picture'})[0].findAll('img')][0]
    except:
        imagepath =""

    logger.info(imagepath)

#    print "==========================================================================="

#==================================================================================================================
#
    education_list = []
    all_cert_tags = soup.find_all('div',{'id':'background-certifications'})
    logger.info("Checking Certificates=================================================================")
    if all_cert_tags:
        for certtags in all_cert_tags:

            for certtag in certtags.find_all('div',{'class' : 'editable-item section-item'}):

                try:
                    certName = certtag.find_all('h4')[0].text
                except:
                    certName = ""
                #print certName
    #           print certtag.find_all('p',{'class' : 'description'})[0].text
                try:
                    schoolname = certtag.find_all(lambda tag: tag.name == 'a' and
                                        tag.findParent('strong') and
                                        tag.findParent('strong').findParent('span'))[0].text
                except:
                    try:
                        schoolname = certtag.find_all(lambda tag: tag.name == 'a' and
                                    tag.findParent('h5'))[0].text
                    except:
                        try:
                            schoolname = certtag.find_all('h5')[0].text
                        except:
                            schoolname = ""
                #print schoolname
                for timetags in certtag.find_all('span', {'class':'certification-date'}):
                    timetag = timetags.find_all('time')
                    # check if list is empty

                    try:
                        certStart = timetag[0].text
                    except:
                        certStart = ""
                    try:
                        certEnd = timetag[1].text
                    except:
                        certEnd = ""

                education_list.append([schoolname,certName, 'cert', certStart, certEnd])
    else:
        logger.info("use old cert")
        all_cert_tags = soup.find_all('ul',{'class':'certifications'})
        logger.info(all_cert_tags)

        if all_cert_tags:
            for cert_tag in all_cert_tags[0].find_all('li', {'class': 'certification'}):
                #print cert_tag

                try:
                    schoolname = cert_tag.find_all('li',{'class':'org'})[0].text.strip('\n').strip()
                except:
                    schoolname = ""
                try:
                    certName = cert_tag.find_all('h3')[0].text.strip('\n').strip()
                except:
                    certName = ""
                try:
                    certStart = cert_tag.find_all('span',{'class':'dtstart'})[0].text.strip('\n').strip()
                except:
                    certStart = ""
                try:
                    certEnd = cert_tag.find_all('span',{'class':'dtend'})[0].text.strip('\n').strip()
                except:
                    certEnd = ""

                education_list.append([schoolname,certName, 'cert', certStart, certEnd])

        logger.info(education_list)

        #print "Cert Start : %s\nCert End : %s\n" % (certStart, certEnd)

#    print "==========================================================================="

#==================================================================================================================
#
    all_education_tags = soup.find_all('div',{'id':'background-education'})
    logger.info("Checking Educations=================================================================")

    if all_education_tags:

        for educationtags in all_education_tags:
            edu_list=[]
            for educationtag in educationtags.find_all ('div',{'class':'education'}):
                logger.info(educationtag)
                schoolname = educationtag.find_all(lambda tag: tag.name == 'a' and
                                        tag.findParent('h4') and
                                        tag.findParent('h4').findParent('header'))[0].text

                notes = educationtag.find_all('p',{'class' : 'notes'})
                if notes:
                    note=notes[0].text
                activities = educationtag.find_all('p',{'class' : 'activities'})
                if activities:
                    activity=activities[0].text
    #                print activity

                majors = educationtag.find_all(lambda tag: tag.name == 'a' and
                                        tag.findParent('span') and
                                        tag.findParent('span').findParent('h5') and
                                        tag.findParent('span').findParent('h5').findParent('header'))

                edutime = educationtag.find_all(lambda tag: tag.name == 'time' and
                                        tag.findParent('span') and
                                        tag.findParent('span').findParent('header'))

                headertags = educationtag.find_all('header')


                for timetags in educationtag.find_all('span', {'class':'education-date'}):
                    timetag = timetags.find_all('time')
                    # check if list is empty

                    try:
                        eduStart = timetag[0].text
                    except:
                        eduStart = ""
                    try:
                        eduEnd = timetag[1].text
                    except:
                        eduEnd = ""

                for headertag in headertags:
                    for degreetag in headertag.find_all('h5'):
                        try:
                            degree = degreetag.find_all('span', {'class':'degree'})[0].text.strip()
                            if degree[-1] == ",":
                                degree = degree[:-1]
                        except:
                            degree = ""
    #                        print degreetag
                            #print degree.text



    #            print schoolname
    #            print "-----\n"
    #            print degree
    #            print "-----\n"
                major_text = ""
                for major in majors:
                    major_text += major.text + ", "
    #                print major.text
                major_text = major_text.strip()

                try:
                    major_text = major_text[:-1]
                except:
                    major_text = ""
    # print "-----\n"
    #            print "Start : %s" % eduStart
    #            print "End : %s" % eduEnd

                education_list.append([schoolname,degree, major_text, eduStart, eduEnd])
    else:
        logger.info("Old Education format")
        all_education_tags = soup.find_all('div',{'class': re.compile("education")})
        if all_education_tags:
            for education_tag in all_education_tags[0].find_all('div', {'class': re.compile("position")}):
                logger.info(education_tag)
                schoolname = education_tag.find_all(lambda tag: tag.name == 'a' and
                                            tag.findParent('h3') )[0].text
                if not schoolname:
                    schoolname = education_tag.find_all('h3')[0].text.strip('\n').strip()


                try:
                    majors = education_tag.find_all('span',{'class':'major'})[0].text.strip('\n').strip()
                except:
                    majors = ""
                try:
                    degree = education_tag.find_all('span',{'class':'degree'})[0].text.strip('\n').strip()
                except:
                    degree = ""

                try:
                    edu_start = education_tag.find_all('abbr',{'class':'dtstart'})[0]['title'].strip('\n').strip()
                except:
                    edu_start = ""
                try:
                    edu_end = education_tag.find_all('abbr',{'class':'dtend'})[0]['title'].strip('\n').strip()
                except:
                    edu_end = ""


                #print schoolname
                #print majors
                #print degree
                #print edu_start
                #print edu_end
                education_list.append([schoolname,degree, majors, edu_start, edu_end])
            #print "========="
        print education_list

#==================================================================================================================
#
    skill_lists = []
    logger.info("Checking Skills=================================================================")
    all_skill_tags = soup.find_all('span',{'class':'skill-pill'})
    if all_skill_tags:
        for skilltags in all_skill_tags:

            try:
                num_endose=skilltags.find_all('span',{'class':'num-endorsements'})[0].text
            except:
                num_endose=""
            try:
                skillname=skilltags.find_all('a',{'class':'endorse-item-name-text'})[0].text
            except:
                try:
                    skillname=skilltags.find_all('span',{'class':'endorse-item-name '})[0].text
                except:
                    skillname=""


            if skillname != '':
    #            print num_endose + " - " + skillname
                skill_lists.append([skillname, num_endose])
    else:
        print "Old profile skill"
        all_skill_tags = soup.find_all('ol',{'id':'skills-list'})
        if all_skill_tags:
            skill_name = all_skill_tags[0].find_all(lambda tag: tag.name == 'span' and tag.findParent('li'))

            for skilltag in skill_name:
                skill_lists.append([skilltag.text.strip().strip('\n').strip(), 0])

    logger.info(skill_lists)
#==================================================================================================================
#
    experiance_lists = []
    all_experience_tags = soup.find_all('div',{'id':'background-experience'})
    logger.info("Checking Experience=================================================================")

    if all_experience_tags:

        for experiencetags in all_experience_tags:
            #print(experiencetags)
            #print "======="
            #experiencetag = experiencetags.find_all('div',{'class' :['editable-item section-item', 'editable-item section-item current-position', 'editable-item section-item past-position']})
            #if not experiencetag:
            #    experiencetag = experiencetags.find_all('div',{'class' :'editable-item section-item current-position'})
            #    if not experiencetag:
            #        experiencetag = experiencetags.find_all('div',{'class' :'editable-item section-item past-position'})

            experiencetag = experiencetags.find_all('div',{'id' :re.compile("^experience-\d*-view")})

            #print experiencetag
            #print "======="
            for exp in experiencetag:
                taglist = exp.find_all('h4')
                try:
                    title = taglist[0].text
                except:
                    title =""
                taglist = exp.find_all('h5')
                for tag in taglist:
                    company = tag.text


                taglist = exp.find_all('p',{'class':'description'})
                try:
                    job_desc = taglist[0].text
                except:
                    job_desc = ""

                timetags = exp.find_all('time')
                try:
                    startTime = timetags[0].text
                except:
                    startTime = ""
                now = datetime.datetime.now()
                try:
                    endTime = timetags[1].text
                except:
                    endTime = datetime.datetime.now().strftime("%b %Y")

                try:
                    company_location = exp.find_all('span',{'class' : 'locality'})[0].text
                except:
                    company_location = ""

                experiance_lists.append([company, title, startTime, endTime])
                #print experiance_lists

    #            print title
    #            print company
    #            print job_desc
    #            print startTime + "  " + endTime
    #            print company_location

            #exit()

    else:

        all_experience_tags = soup.find_all('div', {'class':'position', 'class':'experience'})
        if all_experience_tags:
            #print all_experience_tags
            #.find_all('div', {'class': re.compile("position")})
            all_exp_period_tags = soup.find_all('p', {'class':'period'})
            #print all_exp_period_tags
            i=0
            for experience_tag in all_experience_tags:

                #print experience_tag
                #print "---------------------------"
                title = experience_tag.find_all('span',{'class':'title'})[0].text
                company = experience_tag.find_all('span',{'class':'org summary'})[0].text

                #print company
                #print title

                exp_start = ""
                exp_end = ""

                try:
                    exp_start = experience_tag.find_all('abbr',{'class':'dtstart'})[0]['title'].strip('\n').strip()
                except:
                    try:
                        exp_start = all_exp_period_tags[i].find_all('abbr',{'class':'dtstart'})[0]['title'].strip('\n').strip()
                    except:
                        exp_start = ""

                try:
                    exp_end = all_exp_period_tags[i].find_all('abbr',{'class':'dtstamp'})[0]['title'].strip('\n').strip()
                except:
                    try:
                        exp_end = all_exp_period_tags[i].find_all('abbr',{'class':'dtend'})[0]['title'].strip('\n').strip()
                    except:
                        try:
                            exp_start = all_exp_period_tags[i].find_all('abbr',{'class':'dtstart'})[0]['title'].strip('\n').strip()
                        except:
                            try:
                                exp_start = all_exp_period_tags[i].find_all('abbr',{'class':'dtend'})[0]['title'].strip('\n').strip()
                            except:
                                exp_start = ""

                i += 1
                experiance_lists.append([company, title, exp_start, exp_end])

                #print experiance_lists
                #print "===================================="

    logger.info(experiance_lists)


    logger.info("Inserting into Database=================================================================")
    #locationObj = location(locationText,config, logger)
    if locationObj.city_id == 0:

        print_str = "This profile cannot be process because some city cannot be identified most likely data issue."
        logger.critical(print_str)
        db = dbconnection(config)
        cursor = db.cursor()
        insert_failed = "insert into failed2process (link) values ('%s')" % url_linkedin
        cursor.execute(insert_failed)
        db.commit()
        cursor.close()
        db.close()
        print print_str

    else:
        personObj = person(profilename, locationObj.city_id, url_linkedin, url_twitter, url_personal, url_future1, url_future2, url_future3, url_future4, config)
        logger.info("Inserting into Person=================================================================")

        personObj.save(config, logger)
        logger.info("Person Id : %s" % personObj.id)

        if personObj.is_exist:
            logger.info("Skipped")
        else:

            logger.info("Inserting into Education=================================================================")

            for education in education_list:
                #print education[3] + " = " + education[4]

                month_no = "01"
                date_no = "01"

                try:
                    datetime.datetime.strptime(education[3], '%Y-%m-%d')
                    start_date = education[3]
                except:
                    start = [int(s) for s in education[3].split() if s.isdigit()]
                    try:
                        start_date = date(int(start[0]), int(month_no), int(date_no)).strftime("%Y-%m-%d")
                    except:
                        start_date = ""

                try:
                    datetime.datetime.strptime(education[4], '%Y-%m-%d')
                    end_date = education[4]
                except:
                    end = [int(s) for s in education[4].split() if s.isdigit()]
                    if len(end) != 0:
                        end_date = date(int(end[0]), int(month_no), int(date_no)).strftime("%Y-%m-%d")
                    else:
                        end_date = date.today().strftime("%Y-%m-%d")

                if education[2] == "cert" and education[3] == "":
                    start_date = ""

                if education[2] == "cert" and education[4] == "":
                    end_date = ""

                sch_obj = school(personObj.id, education[0], education[1], education[2], start_date, end_date)
                sch_obj.save(config, logger)
                del sch_obj

    #        print skill_lists
            logger.info("Inserting into Skills=================================================================")

            for skill_set in skill_lists:
    #           print skill_set[0]

                skill_obj = skill(personObj.id, skill_set[0], skill_set[1])
                skill_obj.save(config, logger)
                del skill_obj

            logger.info("Inserting into Experience=================================================================")
            for experiance_list in experiance_lists:
                print experiance_list
                start_date_list = experiance_list[2].split(" ")
                end_date_list = experiance_list[3].split(" ")

                print "Start Date - %s " % start_date_list
                print "End Date - %s " % end_date_list

                try:
                    datetime.datetime.strptime(start_date_list[0], '%Y-%m-%d')
                    start_date = start_date_list[0]
                except:

                    if len(start_date_list) > 1:
                        month_no = month_dict[start_date_list[0]]
                        year_no = start_date_list[1]
                        date_no = "01"
                    else:
                        date_no = "01"
                        month_no = "01"
                        year_no = start_date_list[0]

                    #start = [int(s) for s in start_date_list.split() if s.isdigit()]
                    try:
                        start_date = date(int(year_no), int(month_no), int(date_no)).strftime("%Y-%m-%d")
                    except:
                        start_date = ""

                print start_date

                try:
                    datetime.datetime.strptime(end_date_list[0], '%Y-%m-%d')
                    end_date = end_date_list[0]

                except:

                    if len(end_date_list) > 1:
                        month_no = month_dict[end_date_list[0]]
                        year_no = end_date_list[1]
                        date_no = "01"
                        end_date = date(int(year_no), int(month_no), int(date_no)).strftime("%Y-%m-%d")

                    elif len(end_date_list) == 1:
                        month_no = 12
                        year_no = end_date_list[0]
                        date_no = "01"
                        end_date = date(int(year_no), int(month_no), int(date_no)).strftime("%Y-%m-%d")
                    else:
                        end_date = date.today().strftime("%Y-%m-%d")

                    #end = [int(s) if end_date_list[0].isdigit()]



                print "Experience : " + start_date + " - " + end_date

                exp_obj = experiance(personObj.id, experiance_list[0], experiance_list[1], start_date, end_date)
                exp_obj.save(config, logger)
                del exp_obj
            logger.info("Inserting into Image=================================================================")

            if imagepath:
                img_obj = images(personObj.id, imagepath, 1)
                img_obj.save(config, logger)
                del img_obj
            logger.info("Inserting into Extra Linkedin Info =================================================================")
            if not profiledesc:
                profiledesc = ""
            extra_obj = extraInfo(personObj.id, currenttitle, currentindustry ,profiledesc, "", language_list, interest_list, total_connect, total_recommendation)
            extra_obj.save(config, logger)
            del extra_obj

    return (currenttitle,currentindustry)



