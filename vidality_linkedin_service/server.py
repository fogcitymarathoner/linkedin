__author__ = 'marc'
import cherrypy
import requests
class Root(object):
    def index(self, url=None):
        if url:
            url='https://www.linkedin.com/in/robmcclintic'
            r = requests.get(url)
            return r.text
        else:
            return "Hello World!"
    index.exposed = True


if __name__ == '__main__':

    cherrypy.config.update({
        'server.socket_port': 8100,
        'tools.proxy.on': True,
        'tools.proxy.base': 'localhost',
        'log.access_file': "cherrypy-vidality-linkedin-service-access.log",
        'log.error_file': "cherrypy-vidality-linkedin-server.log",
    })

    cherrypy.quickstart(Root(), '/vidalitylinkedinservice')