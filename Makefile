
help:
	@echo "This Makefile accepts the following targets:"
	@echo "  "
	@echo "    ctan - build the zip file for CTAN upload"
	@echo "   clean - remove intermediate files"
	@echo "    test - run the test script"
	@echo "  "
	@echo "  createbranch - create a git branch for TDS builds"
	@echo "     tdsbranch - upload TDS build to TLContrib & push to Github"
	@echo "  "

.PHONY = help ctan clean checkbranch createbranch tlclogin tdsbuild test

SHELL = /bin/bash
PKG = $(shell basename `pwd`)
CTAN = $(PKG).tar.gz
TDS = $(PKG).tds.zip

# The files generated by processing the .dtx
FROMDTX = $(PKG).aux $(PKG).hd $(PKG).ins $(PKG).log $(PKG).out $(PKG).pdf $(PKG).sty $(PKG).tests $(PKG)-test.tex $(PKG).toc $(PKG).txt

# The files generated by processing $(PKG)-test.tex
FROMTEST = $(PKG)-test.aux $(PKG)-test.log

# All of the files that are generated from other sources
GENERATED = $(FROMDTX) $(FROMTEST) $(CTAN) $(TDS) README

ctan: $(CTAN)

$(CTAN): $(PKG).ins $(PKG).pdf README
	ctanify $^

$(TDS): $(CTAN)
	tar xzf $(CTAN)
	rm -rf $(PKG)/

$(FROMDTX): $(PKG).dtx
	pdflatex $<
	pdflatex $<
	pdflatex $<

README: README.markdown
	cp -f $< $@

$(FROMTEST): $(PKG)-test.tex
	pdflatex $<
	pdflatex $<
	pdflatex $<

test: $(PKG)-test.log

clean:
	@rm -f $(GENERATED)


###### NIGHTLY BUILDS ######

UNAME_S := $(shell uname -s)

# Mac OS X:
ifeq ($(UNAME_S),Darwin)
	MD5 = md5
endif

# Linux:
ifeq ($(UNAME_S),Linux)
	MD5 = md5sum
endif

BRANCH = tdsbuild

TMP = /tmp
LOG =  $(TMP)/gitlog.tmp


checkbranch:
	@if  git branch | grep $(BRANCH) > /dev/null ; \
	then echo "TDS branch exists"; \
	else \
	  echo "TDS branch does not exist; doing so will remove all untracked files from your working directory. Create the TDS branch with\n    make createbranch"; \
	  false; \
	fi;

createbranch: $(TDS)
	cp -f $(TDS) $(TMP)/
	git symbolic-ref HEAD refs/heads/$(BRANCH)
	rm .git/index
	git clean -fdx
	unzip -o $(TMP)/$(TDS) -d .
	rm $(TMP)/$(TDS)
	git add --all
	git commit -m "Initial TDS commit"
	git checkout master
	git push origin $(BRANCH) master
	@echo "\nTDS branch creation was successful.\n"
	@echo "Now create a new package at TLContrib: http://tlcontrib.metatex.org/"
	@echo "Use the following metadata:"
	@echo "    Package ID: $(PKG)"
	@echo "        BRANCH: $(BRANCH)"
	@echo "\nAfter this process, use \`make tdsbuild\` to"
	@echo "    (a) push your recent work on the master branch,"
	@echo "    (b) automatically create a TDS snapshot,"
	@echo "    (c) send the TDS snapshot to TLContrib."


ifeq ($(UNAME_S),Darwin)
  tlclogin:  USERNAME = $(shell security find-internet-password -s tlcontrib.metatex.org | grep "acct" | cut -f 4 -d \")
  tlclogin:  PASSWORD = $(shell security 2>&1 >/dev/null find-internet-password -gs tlcontrib.metatex.org | cut -f 2 -d ' ')
endif

ifeq ($(UNAME_S),Linux)
  tlclogin:  USERNAME = ""
  tlclogin:  PASSWORD = ""
endif

tlclogin:  VERSION = $(shell date "+%Y-%m-%d@%H:%M")
tlclogin: ;

tdsbuild: checkbranch tlclogin $(TDS)
	cp -f $(TDS) $(TMP)/
	@echo "Constructing commit history for snapshot build"
	date "+TDS snapshot %Y-%m-%d %H:%M" > $(LOG)
	echo '\n\nApproximate commit history since last snapshot:\n' >> $(LOG)
	git log --after="`git log -b $(BRANCH) -n 1 --pretty=format:"%aD"`" --pretty=format:"%+H%+s%+b" >> $(LOG)
	@echo "Committing TDS snapshot to separate branch"
	git checkout $(BRANCH)
	unzip -o $(TMP)/$(TDS) -d .
	rm $(TMP)/$(TDS)
	git commit --all --file=$(LOG)
	git clean -df
	@echo "Pushing TDS and master branch"
	git checkout master
	git push origin $(BRANCH) master
	@echo "Pinging TLContrib for automatic update"
	curl http://tlcontrib.metatex.org/cgi-bin/package.cgi/action=notify/key=$(PKG)/check=$(shell echo $(USERNAME)/$(PASSWORD)/$(VERSION) | $(MD5) )?version=$(VERSION) > /dev/null 2>&1



