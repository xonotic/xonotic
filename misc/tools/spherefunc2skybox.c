#include <stdio.h>
#include <err.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>

double rnd()
{
	return rand() / (RAND_MAX + 1.0);
}

typedef void (*mapfunc_t) (double x_in, double y_in, double *x_out, double *y_out, double *z_out);
typedef void (*colorfunc_t) (double x, double y, double z, double *r, double *g, double *b);

void color_test(double x, double y, double z, double *r, double *g, double *b)
{
	// put in a nice function here
	*r = 0.5 + 0.5 * x;
	*g = 0.5 + 0.5 * y;
	*b = 0.5 + 0.5 * z;
}

double mandelbrot_iter(double zx, double zy, double cx, double cy, int maxiter)
{
	double tmp;
	int i;

	double f, fprev;

	f = 0;

	for(i = 1; i < maxiter; ++i)
	{
		tmp = zx;
		zx = zx * zx - zy * zy + cx;
		zy = 2 * tmp * zy + cy;
		fprev = f;
		f = zx * zx + zy * zy;
		if(f > 4)
			break;
	}

	if(i >= maxiter)
		return i;
	else
	{
		// f: the greater, the more in 0 direction
		//    the smaller, the more in 1 direction
		// fprev:
		//    the greater, the more in 0 direction
		return i + 1 / (f - 4 + 1); // f = 16: + 0, f = 4: + 1
	}
	// i.e. 0 for i=1, 1 for i=maxiter
}

double mandelbrot_range(double zx, double zy, double cx, double cy, int maxiter, double offset)
{
	double i = mandelbrot_iter(zx, zy, cx, cy, maxiter);
	// map linearily 1/(offset + iter) so that:
	//   0       -> 0
	//   maxiter -> 1
	// i.e. solve:
	//   f(iter) = A/(offset + iter) + B
	// that is:
	//   f(0)       = A/offset + B = 0
	//   f(maxiter) = A/(offset + maxiter) + B = 1
	// -->
	//   1/(1/(offset + maxiter) - 1/offset) = A
	//   B =          1 + offset / maxiter
	//   A = -offset (1 + offset / maxiter)
	// -->
	//   f(iter) = -offset (1 + offset / maxiter) / (offset + iter) + 1 + offset / maxiter
	//           = -offset (1 + offset / maxiter) / (offset + iter) + 1 + offset / maxiter
	//           = iter (offset + maxiter)   /   maxiter (offset + iter)
	return (i * (offset + maxiter)) / ((i + offset) * maxiter);
}

double color_mandelbrot_parms[13];
double mandelbrot_miniter = -1;
#define MAXITER 8192

double iter_mandelbrot_raw(double x, double y, double z)
{
	z -= color_mandelbrot_parms[6];
	x /= fabs(z);
	y /= fabs(z);

	if(z > 0)
		return mandelbrot_range(color_mandelbrot_parms[4], color_mandelbrot_parms[5], color_mandelbrot_parms[0] + x * color_mandelbrot_parms[2], color_mandelbrot_parms[1] + y * color_mandelbrot_parms[3], MAXITER, color_mandelbrot_parms[9]);
	else
		return 0;
}

void iter_mandelbrot_raw_initialize_min()
{
	if(mandelbrot_miniter >= 0)
		return;
	// randomly sample 256 points
	// mandelbrot them
	// set that as miniter
	int i = 0;
	double x, y, z;
	mandelbrot_miniter = MAXITER;
	for(i = 0; i < 8192; ++i)
	{
		x = rnd() * 2 - 1;
		y = rnd() * 2 - 1;
		z = rnd() * 2 - 1;
		double f = sqrt(x*x + y*y + z*z);
		x /= f;
		y /= f;
		z /= f;
		double a = (z - color_mandelbrot_parms[6]) / (color_mandelbrot_parms[7] - color_mandelbrot_parms[6]);
		a = (a - color_mandelbrot_parms[8]) / (1 - color_mandelbrot_parms[8]);
		if(a < 1)
			continue;
		double iterations = iter_mandelbrot_raw(x, y, z);
		if(iterations == 0)
			continue;
		if(iterations < mandelbrot_miniter)
			mandelbrot_miniter = iterations;
	}
}

void color_mandelbrot(double x, double y, double z, double *r, double *g, double *b)
{
	iter_mandelbrot_raw_initialize_min();

	double iterations = iter_mandelbrot_raw(x, y, z);
	//printf("iter = %f\n", iterations);
	double a = (z - color_mandelbrot_parms[6]) / (color_mandelbrot_parms[7] - color_mandelbrot_parms[6]);
	a = (a - color_mandelbrot_parms[8]) / (1 - color_mandelbrot_parms[8]);
	if(a < 0)
		a = 0;
	if(a > 1)
		a = 1;
	iterations = iterations * a + mandelbrot_miniter * (1-a);
	*r = pow(iterations, color_mandelbrot_parms[10]);
	*g = pow(iterations, color_mandelbrot_parms[11]);
	*b = pow(iterations, color_mandelbrot_parms[12]);
}

void map_back(double x_in, double y_in, double *x_out, double *y_out, double *z_out)
{
	*x_out = 2 * x_in - 1;
	*y_out = +1;
	*z_out = 1 - 2 * y_in;
}

void map_right(double x_in, double y_in, double *x_out, double *y_out, double *z_out)
{
	*x_out = +1;
	*y_out = 1 - 2 * x_in;
	*z_out = 1 - 2 * y_in;
}

void map_front(double x_in, double y_in, double *x_out, double *y_out, double *z_out)
{
	*x_out = 1 - 2 * x_in;
	*y_out = -1;
	*z_out = 1 - 2 * y_in;
}

void map_left(double x_in, double y_in, double *x_out, double *y_out, double *z_out)
{
	*x_out = -1;
	*y_out = 2 * x_in - 1;
	*z_out = 1 - 2 * y_in;
}

void map_up(double x_in, double y_in, double *x_out, double *y_out, double *z_out)
{
	*x_out = 2 * y_in - 1;
	*y_out = 1 - 2 * x_in;
	*z_out = +1;
}

void map_down(double x_in, double y_in, double *x_out, double *y_out, double *z_out)
{
	*x_out = 1 - 2 * y_in;
	*y_out = 1 - 2 * x_in;
	*z_out = -1;
}

void writepic(colorfunc_t f, mapfunc_t m, const char *fn, int width, int height)
{
	int x, y;
	uint8_t tga[18];

	FILE *file = fopen(fn, "wb");
	if(!file)
		err(1, "fopen %s", fn);

	memset(tga, 0, sizeof(tga));
	tga[2] = 2;          // uncompressed type
	tga[12] = (width >> 0) & 0xFF;
	tga[13] = (width >> 8) & 0xFF;
	tga[14] = (height >> 0) & 0xFF;
	tga[15] = (height >> 8) & 0xFF;
	tga[16] = 24;        // pixel size

	fwrite(&tga, sizeof(tga), 1, file);
	for(y = height-1; y >= 0; --y)
		for(x = 0; x < width; ++x)
		{
			uint8_t rgb[3];
			double rr, gg, bb;
			double xx, yy;
			double xxx, yyy, zzz;
			double r;
			xx = (x + 0.5) / width;
			yy = (y + 0.5) / height;
			m(xx, yy, &xxx, &yyy, &zzz);
			r = sqrt(xxx*xxx + yyy*yyy + zzz*zzz);
			xxx /= r;
			yyy /= r;
			zzz /= r;
			f(xxx, yyy, zzz, &rr, &gg, &bb);
			rgb[2] = floor(rnd() + rr * 255);
			rgb[1] = floor(rnd() + gg * 255);
			rgb[0] = floor(rnd() + bb * 255);
			fwrite(rgb, sizeof(rgb), 1, file);
		}
	
	fclose(file);
}

void map_all(const char *fn, colorfunc_t f, int width, int height)
{
	char buf[1024];
	snprintf(buf, sizeof(buf), "%s_bk.tga", fn); buf[sizeof(buf) - 1] = 0; writepic(f, map_back, buf, width, height);
	snprintf(buf, sizeof(buf), "%s_ft.tga", fn); buf[sizeof(buf) - 1] = 0; writepic(f, map_front, buf, width, height);
	snprintf(buf, sizeof(buf), "%s_rt.tga", fn); buf[sizeof(buf) - 1] = 0; writepic(f, map_right, buf, width, height);
	snprintf(buf, sizeof(buf), "%s_lf.tga", fn); buf[sizeof(buf) - 1] = 0; writepic(f, map_left, buf, width, height);
	snprintf(buf, sizeof(buf), "%s_up.tga", fn); buf[sizeof(buf) - 1] = 0; writepic(f, map_up, buf, width, height);
	snprintf(buf, sizeof(buf), "%s_dn.tga", fn); buf[sizeof(buf) - 1] = 0; writepic(f, map_down, buf, width, height);
}

int main(int argc, char **argv)
{
	colorfunc_t f;
	if(argc < 4)
		errx(1, "usage: %s filename res func parms...", *argv);
	int res = atoi(argv[2]);
	if(!strcmp(argv[3], "mandel"))
	{
		f = color_mandelbrot;
		color_mandelbrot_parms[0]  = argc<= 4 ?  -0.740 :  atof(argv[4]); // shift xy
		color_mandelbrot_parms[1]  = argc<= 5 ?  -0.314 :  atof(argv[5]);
		color_mandelbrot_parms[2]  = argc<= 6 ?  -0.003 :  atof(argv[6]); // mul xy
		color_mandelbrot_parms[3]  = argc<= 7 ?  -0.003 :  atof(argv[7]);
		color_mandelbrot_parms[4]  = argc<= 8 ?   0.420 :  atof(argv[8]); // shift z
		color_mandelbrot_parms[5]  = argc<= 9 ?   0.000 :  atof(argv[9]);
		color_mandelbrot_parms[6]  = argc<=10 ?  -0.8   : atof(argv[10]); // horizon
		color_mandelbrot_parms[7]  = argc<=11 ?  -0.7   : atof(argv[11]);
		color_mandelbrot_parms[8]  = argc<=12 ?   0.5   : atof(argv[12]);
		color_mandelbrot_parms[9]  = argc<=13 ? 400     : atof(argv[13]); // coloring
		color_mandelbrot_parms[10] = argc<=14 ?   0.6   : atof(argv[14]);
		color_mandelbrot_parms[11] = argc<=15 ?   0.5   : atof(argv[15]);
		color_mandelbrot_parms[12] = argc<=16 ?   0.2   : atof(argv[16]);
	}
	else
	{
		f = color_test;
	}
	map_all(argv[1], color_mandelbrot, res, res);
	return 0;
}
