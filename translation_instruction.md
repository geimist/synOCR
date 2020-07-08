### You miss your language in synOCR GUI? 

Then, you can help to translate synOCR in your language.  

Translate text only between double quotation marks.  
It is also important that special characters remain in the same place. (e.g. \<br\> / \<b\> …)
  
(The reference file is first [German](https://geimist.eu:30443/geimist/synOCR/src/branch/master/APP/lang/lang_ger.txt), then [English](https://geimist.eu:30443/geimist/synOCR/src/branch/master/APP/lang/lang_enu.txt))

-----

**The following files are needed to translate:**

Mainfile for GUI:
- .[/APP/lang/](https://geimist.eu:30443/geimist/synOCR/src/branch/master/APP/lang)lang_\<language\_code\>.txt

other files for Packetmanagement:   
- .[/PKG/scripts/lang/](https://geimist.eu:30443/geimist/synOCR/src/branch/master/PKG/scripts/lang)**\<language_code\>**
- .[/PKG/WIZARD_UIFILES/](https://geimist.eu:30443/geimist/synOCR/src/branch/master/PKG/WIZARD_UIFILES)uninstall\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- .[/PKG/WIZARD_UIFILES/](https://geimist.eu:30443/geimist/synOCR/src/branch/master/PKG/WIZARD_UIFILES)upgrade\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- .[/PKG/INFO](https://geimist.eu:30443/geimist/synOCR/src/branch/master/PKG/INFO) (➜ only Parameter **"description"** !)
    - description_\<language\_code\>="\<translated description\>"   
  
  
**The following languages are possible:**
- ger = German
- enu = English US
- chs = Chinese simplified
- cht = Chinese traditional
- csy = Czech
- jpn = Japanese
- krn = Korean
- dan = Danish
- fre = French
- ita = Italian
- nld = Dutch
- nor = Norwegian
- plk = Polish
- rus = Russian
- spn = Spanish
- sve = Swedish
- hun = Hungarian
- tha = Tai
- trk = Turkish
- ptg = Portuguese European
- ptb = Portuguese Brazilian
