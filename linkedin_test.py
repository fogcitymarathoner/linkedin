from bs4 import BeautifulSoup as bs
import requests
import os
import sys
import json
from utils.bs_linkedin_scrubber import BeautifulSoupFunction
import logging
urls_html = """<p>&nbsp;<a href="http://ar.linkedin.com/in/marianobuglione" target="_blank" style="font-family: Menlo; font-size: 11px; color: rgb(17, 85, 204);">http://ar.linkedin.com/in/<wbr></wbr>marianobuglione</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ar.linkedin.com/pub/federico-soria-galvarro/25/34b/bb4/en" target="_blank" style="color: rgb(17, 85, 204);">http://ar.linkedin.com/pub/<wbr></wbr>federico-soria-galvarro/25/<wbr></wbr>34b/bb4/en</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://au.linkedin.com/pub/jackson-mead/a7/b85/545/" target="_blank" style="color: rgb(17, 85, 204);">http://au.linkedin.com/pub/<wbr></wbr>jackson-mead/a7/b85/545/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://au.linkedin.com/pub/toby-brain/32/a65/889/" target="_blank" style="color: rgb(17, 85, 204);">http://au.linkedin.com/pub/<wbr></wbr>toby-brain/32/a65/889/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ca.linkedin.com/in/billtraynor/" target="_blank" style="color: rgb(17, 85, 204);">http://ca.linkedin.com/in/<wbr></wbr>billtraynor/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ca.linkedin.com/in/jansteinman/" target="_blank" style="color: rgb(17, 85, 204);">http://ca.linkedin.com/in/<wbr></wbr>jansteinman/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ca.linkedin.com/in/jasonsaobento" target="_blank" style="color: rgb(17, 85, 204);">http://ca.linkedin.com/in/<wbr></wbr>jasonsaobento</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ca.linkedin.com/in/peterhorvath" target="_blank" style="color: rgb(17, 85, 204);">http://ca.linkedin.com/in/<wbr></wbr>peterhorvath</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ca.linkedin.com/in/ramzisfeir/" target="_blank" style="color: rgb(17, 85, 204);">http://ca.linkedin.com/in/<wbr></wbr>ramzisfeir/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ca.linkedin.com/in/ronnyfalk" target="_blank" style="color: rgb(17, 85, 204);">http://ca.linkedin.com/in/<wbr></wbr>ronnyfalk</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://fi.linkedin.com/pub/attila-csipa/2b/668/289/" target="_blank" style="color: rgb(17, 85, 204);">http://fi.linkedin.com/pub/<wbr></wbr>attila-csipa/2b/668/289/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://fr.linkedin.com/in/eduardomucelli/" target="_blank" style="color: rgb(17, 85, 204);">http://fr.linkedin.com/in/<wbr></wbr>eduardomucelli/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://in.linkedin.com/pub/ajay-shankar-bidyarthy/44/632/265/" target="_blank" style="color: rgb(17, 85, 204);">http://in.linkedin.com/pub/<wbr></wbr>ajay-shankar-bidyarthy/44/632/<wbr></wbr>265/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://in.linkedin.com/pub/dilip-dwarak/3b/54/803" target="_blank" style="color: rgb(17, 85, 204);">http://in.linkedin.com/pub/<wbr></wbr>dilip-dwarak/3b/54/803</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://in.linkedin.com/pub/shankar-ananth/58/a93/117/" target="_blank" style="color: rgb(17, 85, 204);">http://in.linkedin.com/pub/<wbr></wbr>shankar-ananth/58/a93/117/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://in.linkedin.com/pub/zakir-hussain/65/446/561/" target="_blank" style="color: rgb(17, 85, 204);">http://in.linkedin.com/pub/<wbr></wbr>zakir-hussain/65/446/561/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://it.linkedin.com/pub/saverio-puddu/54/901/b8/" target="_blank" style="color: rgb(17, 85, 204);">http://it.linkedin.com/pub/<wbr></wbr>saverio-puddu/54/901/b8/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://linkedin.com/in/mike3k" target="_blank" style="color: rgb(17, 85, 204);">http://linkedin.com/in/mike3k</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://linkedin.com/in/orifito/" target="_blank" style="color: rgb(17, 85, 204);">http://linkedin.com/in/<wbr></wbr>orifito/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://lk.linkedin.com/pub/diluka-wittahachchige/47/b37/9b3" target="_blank" style="color: rgb(17, 85, 204);">http://lk.linkedin.com/pub/<wbr></wbr>diluka-wittahachchige/47/b37/<wbr></wbr>9b3</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://lnkd.in/T98F8Z" target="_blank" style="color: rgb(17, 85, 204);">http://lnkd.in/T98F8Z</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://lnkd.in/bVrd-jM" target="_blank" style="color: rgb(17, 85, 204);">http://lnkd.in/bVrd-jM</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://lnkd.in/dN5R3E8" target="_blank" style="color: rgb(17, 85, 204);">http://lnkd.in/dN5R3E8</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://lnkd.in/nfK6mf" target="_blank" style="color: rgb(17, 85, 204);">http://lnkd.in/nfK6mf</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ng.linkedin.com/in/mathewanish/" target="_blank" style="color: rgb(17, 85, 204);">http://ng.linkedin.com/in/<wbr></wbr>mathewanish/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://ua.linkedin.com/pub/andriy-averkiev/28/23/49/" target="_blank" style="color: rgb(17, 85, 204);">http://ua.linkedin.com/pub/<wbr></wbr>andriy-averkiev/28/23/49/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://uk.linkedin.com/pub/john-lewis/a6/12b/27a/" target="_blank" style="color: rgb(17, 85, 204);">http://uk.linkedin.com/pub/<wbr></wbr>john-lewis/a6/12b/27a/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/aaronbrager" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>aaronbrager</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/aaronpruner/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>aaronpruner/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/akiestar" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>akiestar</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/amylew" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>amylew</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/amytam89" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>amytam89</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/andrewyoon" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>andrewyoon</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/anishamangalick/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>anishamangalick/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/arizzitano" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>arizzitano</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/arnotsayjr" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>arnotsayjr</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/bakerkarene/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>bakerkarene/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/brackenspencer/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>brackenspencer/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/brianlindseth/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>brianlindseth/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/carlospliego/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>carlospliego/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/cbergquistbusinessmanagement/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>cbergquistbusinessmanagement/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/christinewendling" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>christinewendling</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/chuchucheng/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>chuchucheng/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/ditheredimage/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>ditheredimage/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/eleanorramachandran/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>eleanorramachandran/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/eliemalkoun/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>eliemalkoun/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/eringeiger" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>eringeiger</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/goldenkrishna" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>goldenkrishna</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/gracechang121/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>gracechang121/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/gregoryjroberts/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>gregoryjroberts/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/guerillero" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>guerillero</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/haydenmsimmons" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>haydenmsimmons</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/inayatchaudhry/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>inayatchaudhry/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/jacquelinjohnson/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>jacquelinjohnson/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/jeanmonsanto" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>jeanmonsanto</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/jenniferdambrosio/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>jenniferdambrosio/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/joannekapsack" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>joannekapsack</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/justinnathankwan/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>justinnathankwan/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/kellerkevin/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>kellerkevin/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/kethryvis/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>kethryvis/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/krishnabrown" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>krishnabrown</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/madelaineplauche" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>madelaineplauche</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/mannydarden" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>mannydarden</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/martinpelemis/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>martinpelemis/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/navyareddy/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>navyareddy/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/pascalkuemper" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>pascalkuemper</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/patwashburn" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>patwashburn</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/paujas" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>paujas</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/qijingfan/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>qijingfan/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/redindhi" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>redindhi</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/reinahashimoto" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>reinahashimoto</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/ricooyola/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>ricooyola/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/rlueder" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>rlueder</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/ryanschmaltz/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>ryanschmaltz/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/samoltrogge/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>samoltrogge/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/sanels/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>sanels/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/scottchauncey" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>scottchauncey</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/scottstadum" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>scottstadum</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/shubasm" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>shubasm</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/suncharles1/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>suncharles1/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/timsparks/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>timsparks/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/twarnold/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>twarnold/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/ubrahmak/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>ubrahmak/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/in/warneronstine/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/in/<wbr></wbr>warneronstine/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/profile/view?id=18914229" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/<wbr></wbr>profile/view?id=18914229</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/ada-liu/3a/575/a/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>ada-liu/3a/575/a/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/aditi-ranade/52/514/905" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>aditi-ranade/52/514/905</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/alyce-kayes/37/934/862/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>alyce-kayes/37/934/862/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/amina-bath/30/895/22b/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>amina-bath/30/895/22b/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/andrea-pomicpic/a3/718/38/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>andrea-pomicpic/a3/718/38/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/anna-matetic/2a/30a/2bb/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>anna-matetic/2a/30a/2bb/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/bezita-lashkariani/a1/8b8/b6b/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>bezita-lashkariani/a1/8b8/b6b/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/christin-roman/24/a5b/b" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>christin-roman/24/a5b/b</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/christina-mattoni-brashear/4/154/15b" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>christina-mattoni-brashear/4/<wbr></wbr>154/15b</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/colette-nataf/44/a63/7b5/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>colette-nataf/44/a63/7b5/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/corey-floyd/5/524/b48/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>corey-floyd/5/524/b48/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/daniel-hebb/12/853/5ab/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>daniel-hebb/12/853/5ab/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/devon-james/a7/989/893/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>devon-james/a7/989/893/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/diana-weisner/4/9/33a/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>diana-weisner/4/9/33a/</a></p>
<p style="color: rgb(34, 34, 34); margin: 0px; font-size: 11px; font-family: Menlo;"><a href="http://www.linkedin.com/pub/gerardo-moad/3/501/b27/" target="_blank" style="color: rgb(17, 85, 204);">http://www.linkedin.com/pub/<wbr></wbr>gerardo-moad/3/501/b27/</a></p>
"""

config = {
    'server',
    'user',
    'pass',
    'database',
}
doc = bs(urls_html)
link_list = []
logger = logging.getLogger(__name__)

user_agent = {'User-agent': 'Mozilla/5.0'}

for link in doc.find_all('a'):
    href = link.get('href')
    try:
        payload = {'url': href}
        r = requests.get('http://69.181.224.185:8081', params=payload, headers = user_agent)

        d = bs(r.text)
        BeautifulSoupFunction(r.text, href, config, logger)
        link_list.append(href)
        print r.status_code
    except:
        print '%s FAILED'%href
