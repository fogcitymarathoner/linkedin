__author__ = 'marc'
import os
import time
page_size = 1000
first = 34*page_size
last = 100*page_size

for start in  range(first, last, page_size):
    end = start+page_size-1
    range_readable = "%s - %s"%(start, end)
    # perl server.pl -start 100 -end 110 -outsql 100-110.sql
    cmd = 'perl server.pl -start %s -end %s -outsql %s-%s.sql'%(start,end,start,end)
    os.system('echo %s'%range_readable)
    os.system('echo %s'%cmd)
    time.sleep(600)