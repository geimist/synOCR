### You miss your language in synOCR GUI? 

Then, you can help to translate synOCR in your language.  

Translate text only between double quotation marks.  
It is also important that special characters remain in the same place. (e.g. \<br\> / \<b\> …)
  
(The reference file is first [German](https://git.geimist.eu/geimist/synOCR/src/branch/master/APP/lang/lang_ger.txt), then [English](https://git.geimist.eu/geimist/synOCR/src/branch/master/APP/lang/lang_enu.txt))

For questions: synocr [@] geimist.eu

-----

**The following files are needed to translate:**

File 1 - mainfile for GUI (most important):
- .[/APP/ui/lang/](https://git.geimist.eu/geimist/synOCR/src/branch/master/APP/ui/lang)lang_\<language\_code\>.txt

other files for packetmanagement:   
- File 2: .[/PKG_DSM6/scripts/lang/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM6/scripts/lang)**\<language_code\>**
- File 3: .[/PKG_DSM6/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM6/WIZARD_UIFILES)uninstall\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- File 4: .[/PKG_DSM6/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM6/WIZARD_UIFILES)upgrade\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- File 5: .[/PKG_DSM6/INFO](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM6/INFO) (➜ only Parameter **"description"** !)
    - description_\<language\_code\>="\<translated description\>"   

- File 6: .[/PKG_DSM7/scripts/lang/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM7/scripts/lang)**\<language_code\>**
- File 7: .[/PKG_DSM7/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM7/WIZARD_UIFILES)uninstall\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- File 8: .[/PKG_DSM7/WIZARD_UIFILES/](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM7/WIZARD_UIFILES)upgrade\_uifile\_**\<language\_code\>** (➜ only Parameter **"step_title"** and **"desc"** !)
- File 9: .[/PKG_DSM7/INFO](https://git.geimist.eu/geimist/synOCR/src/branch/master/PKG_DSM7/INFO) (➜ only Parameter **"description"** !)
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
