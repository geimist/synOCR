### You miss your language in synOCR GUI? 

Then, you can help to translate synOCR in your language.  

Translate text only between double quotation marks.  
It is also important that special characters remain in the same place. (e.g. \<br\> / \<b\> …)
  
(The reference file is first [German](https://git.geimist.eu/geimist/synOCR/src/branch/master/APP/lang/lang_ger.txt), then [English](https://git.geimist.eu/geimist/synOCR/src/branch/master/APP/lang/lang_enu.txt))

For questions: synocr [@] geimist.eu

-----

**The following files are needed to translate:**

Mainfile for GUI:
- .[/APP/ui/lang/](https://git.geimist.eu/geimist/synOCR/src/branch/master/APP/ui/lang)lang_\<language\_code\>.txt

other files for Packetmanagement:   
- .[/PKG_DSM6/scripts/lang/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/scripts/lang)**\<language_code\>**
- .[/PKG_DSM6/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/WIZARD_UIFILES)uninstall\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- .[/PKG_DSM6/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/WIZARD_UIFILES)upgrade\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- .[/PKG_DSM6/INFO](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/INFO) (➜ only Parameter **"description"** !)
    - description_\<language\_code\>="\<translated description\>"   

- .[/PKG_DSM7/scripts/lang/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/scripts/lang)**\<language_code\>**
- .[/PKG_DSM7/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/WIZARD_UIFILES)uninstall\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- .[/PKG_DSM7/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/WIZARD_UIFILES)upgrade\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- .[/PKG_DSM7/INFO](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG/INFO) (➜ only Parameter **"description"** !)
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
