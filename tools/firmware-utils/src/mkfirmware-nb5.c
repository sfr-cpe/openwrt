/*
 *      mkfirmware.c
 *      
 *      Copyright 2007 Miguel GAIO <miguel.gaio@efixo.com>
 *      
 *      This program is free software; you can redistribute it and/or modify
 *      it under the terms of the GNU General Public License as published by
 *      the Free Software Foundation; either version 2 of the License, or
 *      (at your option) any later version.
 *      
 *      This program is distributed in the hope that it will be useful,
 *      but WITHOUT ANY WARRANTY; without even the implied warranty of
 *      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *      GNU General Public License for more details.
 *      
 *      You should have received a copy of the GNU General Public License
 *      along with this program; if not, write to the Free Software
 *      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *      MA 02110-1301, USA.
 */

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <ctype.h>
#include <limits.h>
#include <string.h>
#include <zlib.h>
#include <getopt.h>
#include <unistd.h>
#include <stdint.h>

#include <sys/types.h>

struct firmware_tag {
	char magic[8];
	char name[64];
	char key[8];
	char dummy[28];
	char size[12];
	uint32_t fwcc;
	uint32_t cc;
};
struct firmware_tag tag;

size_t firmware_size(FILE * fp)
{
	long size;

	fseek(fp, 0, SEEK_END);
	size = ftell(fp);
	fseek(fp, 0, SEEK_SET);

	return size;
}

char *strtoupper(char *s)
{
	char *p = s;

	while (*p) {
		*p = toupper(*p);
		++p;
	}

	return s;
}

int main(int argc, char *argv[])
{
	char const *in;
	char *out;
	uint8_t *buffer;
	FILE *ifp, *ofp;
	size_t size;

	if (argc < 3) {
		fprintf(stderr, "usage: %s <in> <out>\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	in = argv[1];
	out = argv[2];

	ifp = fopen(in, "r");
	if (!ifp) {
		printf("fopen( %s, %s ) %m", in, "r");
		exit(EXIT_FAILURE);
	}
	ofp = fopen(out, "w");
	if (!ofp) {
		printf("fopen( %s, %s ) %m", out, "w");
		exit(EXIT_FAILURE);
	}

	/* set size */
	size = firmware_size(ifp);

	if ((buffer = malloc(size)) == NULL) {
		perror("malloc()");
		exit(EXIT_FAILURE);
	}

	if (fread(buffer, 1, size, ifp) != size) {
		perror("fread()");
		exit(EXIT_FAILURE);
	}

	/* clear TAG */
	memset(&tag, 0x00, sizeof(tag));

	/* set magic */
	strcpy(tag.magic, "!eFiXo");

	/* set name */
	snprintf(tag.name, sizeof(tag.name), "%s", strtoupper(basename(out)));

	snprintf(tag.size, sizeof(tag.size), "%lu", size);

	/* fill dummy */
	memset(tag.dummy, 0xcc, sizeof(tag.dummy));

	/* compute firmware cc */
	tag.fwcc = htonl(crc32('F', buffer, size));

	/* compute tag cc */
	tag.cc =
	    htonl(crc32('T', (uint8_t *) & tag, sizeof(tag) - sizeof(tag.cc)));

	fwrite(&tag, sizeof(tag), 1, ofp);
	fwrite(buffer, 1, size, ofp);

	fclose(ifp);
	fclose(ofp);

	printf("--\n");
	printf("firwmare: version: %s size %s crc32 %08X\n", tag.name,
	       tag.size, tag.fwcc);

	return 0;
}
