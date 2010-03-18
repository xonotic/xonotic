#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdarg.h>
#include <errno.h>

void err(int ex, const char *fmt, ...)
{
	va_list list;
	int e = errno;
	va_start(list, fmt);
	vfprintf(stderr, fmt, list);
	fputs(": ", stderr);
	fputs(strerror(e), stderr);
	fputs("\n", stderr);
	exit(ex);
}

void errx(int ex, const char *fmt, ...)
{
    va_list list;
    va_start(list, fmt);
    vfprintf(stderr, fmt, list);
    fputs("\n", stderr);
    exit(ex);
}

typedef void (*colorfunc_t) (double x, double y, double dx, double dy, double *r, double *g, double *b);

double rnd()
{
	return rand() / (RAND_MAX + 1.0);
}

double softclip(double x, double a)
{
	// don't ask what this does - but it works
	double cse = (2*a*x - x - a + 1) * x;
	return cse / (cse + (1 - a));
}

void writepic(colorfunc_t f, const char *fn, int width, int height)
{
	int x, y;
	uint8_t tga[18];

	FILE *file = fopen(fn, "wb");
	if(!file)
		err(1, "fopen >%s", fn);

	memset(tga, 0, sizeof(tga));
	tga[2] = 2;          // uncompressed type
	tga[12] = (width >> 0) & 0xFF;
	tga[13] = (width >> 8) & 0xFF;
	tga[14] = (height >> 0) & 0xFF;
	tga[15] = (height >> 8) & 0xFF;
	tga[16] = 24;        // pixel size

	if(fwrite(&tga, sizeof(tga), 1, file) != 1)
		err(1, "fwrite >%s", fn);
	//for(y = height-1; y >= 0; --y)
	for(y = 0; y < height; ++y)
		for(x = 0; x < width; ++x)
		{
			uint8_t rgb[3];
			double rr, gg, bb;
			double xx, yy;
			xx = (x + 0.5) / width;
			yy = (y + 0.5) / height;
			f(xx, yy, 0.5 / width, 0.5 / height, &rr, &gg, &bb);
			rgb[2] = floor(rnd() + rr * 255);
			rgb[1] = floor(rnd() + gg * 255);
			rgb[0] = floor(rnd() + bb * 255);
			if(fwrite(rgb, sizeof(rgb), 1, file) != 1)
				err(1, "fwrite >%s", fn);
		}
	
	fclose(file);
}

typedef struct
{ 
	double x, y, dist;
	int weapon;
}
plotpoint_t;

plotpoint_t *plotpoints;
size_t nPlotpoints, allocatedPlotpoints;

void readpoints(const char *fn)
{
	char buf[1024];

	FILE *infile = fopen(fn, "r");
	if(!infile)
		err(1, "fopen <%s", fn);

	nPlotpoints = allocatedPlotpoints = 0;
	plotpoints = NULL;

	while(fgets(buf, sizeof(buf), infile))
	{
		if(*buf == '#') 
		{
			fputs(buf + 1, stdout);
			continue;
		}
		if(nPlotpoints >= allocatedPlotpoints)
		{
			if(allocatedPlotpoints == 0)
				allocatedPlotpoints = 1024;
			else
				allocatedPlotpoints = nPlotpoints * 2;
			plotpoints = (plotpoint_t *) realloc(plotpoints, allocatedPlotpoints * sizeof(*plotpoints));
		}
		if(sscanf(buf, "%lf %lf %lf %d", &plotpoints[nPlotpoints].x, &plotpoints[nPlotpoints].y, &plotpoints[nPlotpoints].dist, &plotpoints[nPlotpoints].weapon) != 4)
			continue;
		++nPlotpoints;
	}
}

void calcplot1(double x, double y, double *out, double sigma2)
{
	size_t i;
	double dist2;
	double val, totalval = 0, weight, totalweight = 0;

	for(i = 0; i < nPlotpoints; ++i)
	{
		dist2 = (x - plotpoints[i].x) * (x - plotpoints[i].x) + (y - plotpoints[i].y) * (y - plotpoints[i].y);
		weight = 1; // / plotpoints[i].dist;
		val = exp(-dist2 / sigma2);

		totalweight += weight;
		totalval += weight * val;
	}

	*out = softclip(totalval / (totalweight * sqrt(sigma2 * 2 * M_PI)), 0.8);
}

void calcplotp(double x, double y, double dx, double dy, double *out)
{
	size_t i;
	double distx, disty;

	for(i = 0; i < nPlotpoints; ++i)
	{
		distx = x - plotpoints[i].x;
		disty = y - plotpoints[i].y;

		if(distx < dx)
		if(distx > -dx)
		if(disty < dy)
		if(disty > -dy)
		{
			*out = 1;
			break;
		}
	}
}

void calcplot(double x, double y, double dx, double dy, double *r, double *g, double *b)
{
	calcplot1(x, y, r, 1/64.0);
	calcplot1(x, y, g, 1/512.0);
	calcplot1(x, y, b, 1/4096.0);
	calcplotp(x, y, dx, dy, b);
}

int main(int argc, char **argv)
{
	if(argc != 3)
		errx(1, "Usage: %s infile.plot outfile.tga", *argv);
	
	readpoints(argv[1]);
	writepic(calcplot, argv[2], 512, 512);

	return 0;
}
