SOURCE_FILE = main
INSTALL_PATH = /usr/local/bin
OUTPUT = sf

main:
	cc -c $(SOURCE_FILE).s -o $(SOURCE_FILE).o
	cc $(SOURCE_FILE).o -o $(OUTPUT)
	rm $(SOURCE_FILE).o

clean:
	rm -f $(OUTPUT)

install:
	cp -f $(OUTPUT) $(INSTALL_PATH)
