#! /bin/bash
tar -cvf msp.tar tar.sh 0readme doc/*.htm doc/*.pdf src/makefile src/ms*.h src/ms*.c \
 mac/* win/*.exe sgi/* sun/* pdb/*.pdb scripts/*.sh scripts/*.script scripts/*.sel
compress msp.tar
