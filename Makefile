
PKG = $(shell basename `pwd`)
FILES = README $(PKG).ins $(PKG).dtx
RESULTS = $(PKG).pdf $(PKG).sty

$(PKG).tar.gz: $(FILES) $(RESULTS)
	ctanify $(PKG).ins $(PKG).pdf README

$(PKG).ins: $(PKG).dtx
	tex $<

$(PKG).pdf: $(PKG).dtx
	pdflatex $<
	pdflatex $<
	pdflatex $<

$(PKG).sty: $(PKG).ins
	tex $<

README: README.markdown
	cp -f $< $@

.PHONY: clean

clean:
	rm -f $(RESULTS) $(PKG).ins README $(PKG).aux $(PKG).log $(PKG).pdf $(PKG).idx $(PKG).tar.gz

