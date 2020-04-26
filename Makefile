
.SUFFIXES: .mod .txt .html .mtc .blo .tgz .tex .dvi .ps

MOD2TEXT = ./m2t 
MOD2TEX  = ./m2T 
MOD2HTML = ./m2h 
MODOPTIONS = -c1
DVIPS = dvips

.mod.txt:  
	$(MOD2TEXT) $(MODOPTIONS) $*.mod > $*.txt

.mod.html:  
	$(MOD2HTML) $(MODOPTIONS) $*.mod > $*.html

.mod.tex:  
	$(MOD2TEX) $(MODOPTIONS)  $*.mod > $*.tex

.tex.dvi:  
	tex $*.tex 

.dvi.ps:  
	$(DVIPS) -o $*.ps $*.dvi

.mod.mtc:  
	$(MOD2TEXT) $(MODOPTIONS) $*.mod >> /dev/null

.mod.blo:
	blowfish -ck '$(KEY)' $*.mod > $*.blo

.tgz.blo:
	blowfish -ck '$(KEY)' $*.tgz > $*.blo

MOD= sample.mod 

TXT = sample.txt  
HTML= sample.html
PS= sample.ps 

MTC= sample.mtc

all: $(TXT) $(HTML) mtc # $(PS)

$(TXT): $(MOD2TEXT)  Mod/Text.pm # ./mathescapes 

$(HTML): $(MOD2HTML) Mod/HTML.pm  # ./mathescapes 

$(TEX): $(MOD2TEX)  Mod/TeX.pm # ./mathescapes 

mtc: $(MTC)
	cat $(MTC) > mtc

./mathescapes: ./badmath
	./defmath
	rm ./badmath

clean: 
	rm -f $(TXT)
	rm -f mtc badmath

wc:	.wc
	@cat .wc

.wc:	$(TXT)
	@wc $(TXT) > .wc

