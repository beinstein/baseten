PREFIX = ../images/
TARGETS = \
	class-hierarchy.pdf \
	class-hierarchy.png \
	object-relationships.pdf \
	object-relationships.png \
	connect.eps \
	connect.png \
	update-change-propagation.eps \
	update-change-propagation.png


all: $(TARGETS)
	mv $(TARGETS) $(PREFIX)


clean:
	rm -f $(TARGETS) $(addprefix $(PREFIX),$(TARGETS))


%.png : %.msc
	$(MSCGEN) -T png -o $@ $<


%.eps : %.msc
	$(MSCGEN) -T eps -o $@ $<


%.pdf : %.dot
	$(DOT) -Tpdf -o$@ $<


%.png : %.dot
	$(DOT) -Tpng -o$@ $<
