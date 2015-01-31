author__ = 'marc'

import cherrypy
import tenjin
import os
import sys
from tenjin.helpers import *
import json
import re
import pickle
import pytz


import cgi
import tempfile

from lib import get_skills

import sqlite3 as lite

class myFieldStorage(cgi.FieldStorage):
    """Our version uses a named temporary file instead of the default
    non-named file; keeping it visibile (named), allows us to create a
    2nd link after the upload is done, thus avoiding the overhead of
    making a copy to the destination filename."""

    def make_file(self, binary=None):
        return tempfile.NamedTemporaryFile()


def noBodyProcess():
    """Sets cherrypy.request.process_request_body = False, giving
    us direct control of the file upload destination. By default
    cherrypy loads it to memory, we are directing it to disk."""
    cherrypy.request.process_request_body = False

cherrypy.tools.noBodyProcess = cherrypy.Tool('before_request_body', noBodyProcess)


class Root(object):

    @cherrypy.expose
    def index(self):
        """Simplest possible HTML file upload form. Note that the encoding
        type must be multipart/form-data."""

        return """
            <html>
            <body>
                <form action="upload" method="post" enctype="multipart/form-data">
                    File: <input type="file" name="theFile"/> <br/>
                    <input type="submit"/>
                </form>
            </body>
            </html>
            """

    @cherrypy.expose
    @cherrypy.tools.noBodyProcess()
    def upload(self, theFile=None):
        """upload action

        We use our variation of cgi.FieldStorage to parse the MIME
        encoded HTML form data containing the file."""

        ## create engine object
        engine = tenjin.Engine(path=['views'])
        # the file transfer can take a long time; by default cherrypy
        # limits responses to 300s; we increase it to 1h
        cherrypy.response.timeout = 3600

        # convert the header keys to lower case
        lcHDRS = {}
        for key, val in cherrypy.request.headers.iteritems():
            lcHDRS[key.lower()] = val

        # at this point we could limit the upload on content-length...
        # incomingBytes = int(lcHDRS['content-length'])

        # create our version of cgi.FieldStorage to parse the MIME encoded
        # form data where the file is contained
        formFields = myFieldStorage(fp=cherrypy.request.rfile,
                                    headers=lcHDRS,
                                    environ={'REQUEST_METHOD':'POST'},
                                    keep_blank_values=True)

        # we now create a 2nd link to the file, using the submitted
        # filename; if we renamed, there would be a failure because
        # the NamedTemporaryFile, used by our version of cgi.FieldStorage,
        # explicitly deletes the original filename
        theFile = formFields['theFile']
        #os.link(theFile.file.name, '/tmp/'+theFile.filename)
        outbase = os.path.splitext(os.path.basename(theFile.filename))[0]
        txtfile = os.path.join(os.sep, 'tmp', outbase)+'.txt'
        os.system('pdf2txt.py -o "%s" %s'%(txtfile, theFile.filename))

        f = open(txtfile, 'r')
        data = f.read()

        if os.path.isfile(txtfile):
            os.remove(txtfile)
        if os.path.isfile(theFile.filename):
            os.remove(theFile.filename)
        skills = get_skills(data)
        db = lite.connect('test.db')
        cursor = db.cursor()
        for skl in skills:
            q = 'insert into skills (\'name\') values (\'%s\')'%skl
            try:
              cursor.execute(q)
              db.commit()
            except lite.IntegrityError:
              print "Skill %s already exists"%skl

        context = {
            'skills': skills,
        }
        ## render template with context data
        html = engine.render('skills.pyhtml', context)
        return html

if __name__ == '__main__':

    cherrypy.config.update({
        'server.socket_port': 8095,
        'tools.proxy.on': True,
        'tools.proxy.base': 'localhost',
        'log.access_file': "cherrypy-filter-access.log",
        'log.error_file': "cherrypy-filter.log",
    })

    cherrypy.quickstart(Root(), '/vidalityresumeservice')


