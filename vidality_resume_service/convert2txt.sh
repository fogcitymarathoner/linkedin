#!/bin/bash
for file in *.pdf
do  
	b=`basename $file` 
	pdf2txt.py $file > $b.txt
done

