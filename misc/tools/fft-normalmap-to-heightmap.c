/*
 *  FFT based normalmap to heightmap converter
 *  Copyright (C) 2010  Rudolf Polzer
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#undef C99
#if __STDC_VERSION__ >= 199901L
#define C99
#endif

#ifdef C99
#include <complex.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <fftw3.h>

#define TWO_PI (4*atan2(1,1) * 2)

void nmap_to_hmap(unsigned char *map, const unsigned char *refmap, int w, int h, double scale, double offset, const double *filter, int filterw, int filterh, int renormalize, double highpass)
{
	int x, y;
	int i, j;
	double fx, fy;
	double ffx, ffy;
	double nx, ny, nz;
	double v, vmin, vmax;
#ifndef C99
	double save;
#endif

	fftw_complex *imgspace1 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_complex *imgspace2 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_complex *freqspace1 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_complex *freqspace2 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_plan i12f1 = fftw_plan_dft_2d(h, w, imgspace1, freqspace1, FFTW_FORWARD, FFTW_ESTIMATE);
	fftw_plan i22f2 = fftw_plan_dft_2d(h, w, imgspace2, freqspace2, FFTW_FORWARD, FFTW_ESTIMATE);
	fftw_plan f12i1 = fftw_plan_dft_2d(h, w, freqspace1, imgspace1, FFTW_BACKWARD, FFTW_ESTIMATE);

	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
		/*
		 * unnormalized normals:
		 * n_x = -dh/dx
		 * n_y = -dh/dy
		 * n_z = -dh/dh = -1
		 * BUT: darkplaces uses inverted normals, n_y actually is dh/dy by image pixel coordinates
		 */
		nx = ((int)map[(w*y+x)*4+2] - 127.5) / 128;
		ny = ((int)map[(w*y+x)*4+1] - 127.5) / 128;
		nz = ((int)map[(w*y+x)*4+0] - 127.5) / 128;

		/* reconstruct the derivatives from here */
#ifdef C99
		imgspace1[(w*y+x)] =  nx / nz * w; /* = dz/dx */
		imgspace2[(w*y+x)] = -ny / nz * h; /* = dz/dy */
#else
		imgspace1[(w*y+x)][0] =  nx / nz * w; /* = dz/dx */
		imgspace1[(w*y+x)][1] = 0;
		imgspace2[(w*y+x)][0] = -ny / nz * h; /* = dz/dy */
		imgspace2[(w*y+x)][1] = 0;
#endif

		if(renormalize)
		{
			double v = nx * nx + ny * ny + nz * nz;
			if(v > 0)
			{
				v = 1/sqrt(v);
				nx *= v;
				ny *= v;
				nz *= v;
				map[(w*y+x)*4+2] = floor(nx * 127.5 + 128);
				map[(w*y+x)*4+1] = floor(ny * 127.5 + 128);
				map[(w*y+x)*4+0] = floor(nz * 127.5 + 128);
			}
		}
	}

	/* see http://www.gamedev.net/community/forums/topic.asp?topic_id=561430 */

	fftw_execute(i12f1);
	fftw_execute(i22f2);
	
	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
		fx = x * 1.0 / w;
		fy = y * 1.0 / h;
		if(fx > 0.5)
			fx -= 1;
		if(fy > 0.5)
			fy -= 1;
		if(filter)
		{
			// discontinous case
			// we must invert whatever "filter" would do on (x, y)!
#ifdef C99
			fftw_complex response_x = 0;
			fftw_complex response_y = 0;
			double sum;
			for(i = -filterh / 2; i <= filterh / 2; ++i)
				for(j = -filterw / 2; j <= filterw / 2; ++j)
				{
					response_x += filter[(i + filterh / 2) * filterw + j + filterw / 2] * cexp(-_Complex_I * TWO_PI * (j * fx + i * fy));
					response_y += filter[(i + filterh / 2) * filterw + j + filterw / 2] * cexp(-_Complex_I * TWO_PI * (i * fx + j * fy));
				}

			// we know:
			//   fourier(df/dx)_xy = fourier(f)_xy * response_x
			//   fourier(df/dy)_xy = fourier(f)_xy * response_y
			// mult by conjugate of response_x, response_y:
			//   conj(response_x) * fourier(df/dx)_xy = fourier(f)_xy * |response_x^2|
			//   conj(response_y) * fourier(df/dy)_xy = fourier(f)_xy * |response_y^2|
			// and
			//   fourier(f)_xy = (conj(response_x) * fourier(df/dx)_xy + conj(response_y) * fourier(df/dy)_xy) / (|response_x|^2 + |response_y|^2)

			sum = cabs(response_x) * cabs(response_x) + cabs(response_y) * cabs(response_y);

			if(sum > 0)
				freqspace1[(w*y+x)] = (conj(response_x) * freqspace1[(w*y+x)] + conj(response_y) * freqspace2[(w*y+x)]) / sum;
			else
				freqspace1[(w*y+x)] = 0;
#else
			fftw_complex response_x = {0, 0};
			fftw_complex response_y = {0, 0};
			double sum;
			for(i = -filterh / 2; i <= filterh / 2; ++i)
				for(j = -filterw / 2; j <= filterw / 2; ++j)
				{
					response_x[0] += filter[(i + filterh / 2) * filterw + j + filterw / 2] * cos(-TWO_PI * (j * fx + i * fy));
					response_x[1] += filter[(i + filterh / 2) * filterw + j + filterw / 2] * sin(-TWO_PI * (j * fx + i * fy));
					response_y[0] += filter[(i + filterh / 2) * filterw + j + filterw / 2] * cos(-TWO_PI * (i * fx + j * fy));
					response_y[1] += filter[(i + filterh / 2) * filterw + j + filterw / 2] * sin(-TWO_PI * (i * fx + j * fy));
				}

			sum = response_x[0] * response_x[0] + response_x[1] * response_x[1]
			    + response_y[0] * response_y[0] + response_y[1] * response_y[1];

			if(sum > 0)
			{
				double s = freqspace1[(w*y+x)][0];
				freqspace1[(w*y+x)][0] = (response_x[0] * s                      + response_x[1] * freqspace1[(w*y+x)][1] + response_y[0] * freqspace2[(w*y+x)][0] + response_y[1] * freqspace2[(w*y+x)][1]) / sum;
				freqspace1[(w*y+x)][1] = (response_x[0] * freqspace1[(w*y+x)][1] - response_x[1] * s                      + response_y[0] * freqspace2[(w*y+x)][1] - response_y[1] * freqspace2[(w*y+x)][0]) / sum;
			}
			else
			{
				freqspace1[(w*y+x)][0] = 0;
				freqspace1[(w*y+x)][1] = 0;
			}
#endif
		}
		else
		{
			// continuous integration case
			/* these must have the same sign as fx and fy (so ffx*fx + ffy*fy is nonzero), otherwise do not matter */
			/* it basically decides how artifacts are distributed */
			ffx = fx;
			ffy = fy;
#ifdef C99
			if(fx||fy)
				freqspace1[(w*y+x)] = _Complex_I * (ffx * freqspace1[(w*y+x)] + ffy * freqspace2[(w*y+x)]) / (ffx*fx + ffy*fy) / TWO_PI;
			else
				freqspace1[(w*y+x)] = 0;
#else
			if(fx||fy)
			{
				save = freqspace1[(w*y+x)][0];
				freqspace1[(w*y+x)][0] = -(ffx * freqspace1[(w*y+x)][1] + ffy * freqspace2[(w*y+x)][1]) / (ffx*fx + ffy*fy) / TWO_PI;
				freqspace1[(w*y+x)][1] =  (ffx * save + ffy * freqspace2[(w*y+x)][0]) / (ffx*fx + ffy*fy) / TWO_PI;
			}
			else
			{
				freqspace1[(w*y+x)][0] = 0;
				freqspace1[(w*y+x)][1] = 0;
			}
#endif
		}
		if(highpass > 0)
		{
			double f1 = (fabs(fx)*highpass);
			double f2 = (fabs(fy)*highpass);
			// if either of them is < 1, phase out (min at 0.5)
			double f =
				(f1 <= 0.5 ? 0 : (f1 >= 1 ? 1 : ((f1 - 0.5) * 2.0)))
				*
				(f2 <= 0.5 ? 0 : (f2 >= 1 ? 1 : ((f2 - 0.5) * 2.0)));
#ifdef C99
			freqspace1[(w*y+x)] *= f;
#else
			freqspace1[(w*y+x)][0] *= f;
			freqspace1[(w*y+x)][1] *= f;
#endif
		}
	}

	fftw_execute(f12i1);

	/* renormalize, find min/max */
	vmin = vmax = 0;
	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
#ifdef C99
		v = creal(imgspace1[(w*y+x)] /= pow(w*h, 1.5));
#else
		v = (imgspace1[(w*y+x)][0] /= pow(w*h, 1.5));
		// imgspace1[(w*y+x)][1] /= pow(w*h, 1.5);
		// this value is never used
#endif
		if(v < vmin || (x == 0 && y == 0))
			vmin = v;
		if(v > vmax || (x == 0 && y == 0))
			vmax = v;
	}

	if(refmap)
	{
		double f, a;
		double o, s;
		double sa, sfa, sffa, sfva, sva;
		double mi, ma;
		sa = sfa = sffa = sfva = sva = 0;
		mi = 1;
		ma = -1;
		for(y = 0; y < h; ++y)
		for(x = 0; x < w; ++x)
		{
			a = (int)refmap[(w*y+x)*4+3];
			v = (refmap[(w*y+x)*4+0]*0.114 + refmap[(w*y+x)*4+1]*0.587 + refmap[(w*y+x)*4+2]*0.299);
			v = (v - 128.0) / 127.0;
#ifdef C99
			f = creal(imgspace1[(w*y+x)]);
#else
			f = imgspace1[(w*y+x)][0];
#endif
			if(a <= 0)
				continue;
			if(v < mi)
				mi = v;
			if(v > ma)
				ma = v;
			sa += a;
			sfa += f*a;
			sffa += f*f*a;
			sfva += f*v*a;
			sva += v*a;
		}
		if(mi < ma)
		{
			/* linear regression ftw */
			o = (sfa*sfva - sffa*sva) / (sfa*sfa-sa*sffa);
			s = (sfa*sva - sa*sfva) / (sfa*sfa-sa*sffa);
		}
		else /* all values of v are equal, so we cannot get scale; we can still get offset */
		{
			o = ((sva - sfa) / sa);
			s = 1;
		}

		/*
		 * now apply user-given offset and scale to these values
		 * (x * s + o) * scale + offset
		 * x * s * scale + o * scale + offset
		 */
		offset += o * scale;
		scale *= s;
	}
	else if(scale == 0)
	{
		/*
		 * map vmin to -1
		 * map vmax to +1
		 */
		scale = 2 / (vmax - vmin);
		offset = -(vmax + vmin) / (vmax - vmin);
	}

	printf("Min: %f\nAvg: %f\nMax: %f\nScale: %f\nOffset: %f\nScaled-Min: %f\nScaled-Avg: %f\nScaled-Max: %f\n", 
		vmin, 0.0, vmax, scale, offset, vmin * scale + offset, offset, vmax * scale + offset);

	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
#ifdef C99
		v = creal(imgspace1[(w*y+x)]);
#else
		v = imgspace1[(w*y+x)][0];
#endif
		v = v * scale + offset;
		if(v < -1)
			v = -1;
		if(v > 1)
			v = 1;
		map[(w*y+x)*4+3] = floor(128.5 + 127 * v);
	}

	fftw_destroy_plan(i12f1);
	fftw_destroy_plan(i22f2);
	fftw_destroy_plan(f12i1);

	fftw_free(freqspace2);
	fftw_free(freqspace1);
	fftw_free(imgspace2);
	fftw_free(imgspace1);
}

void hmap_to_nmap(unsigned char *map, int w, int h, int src_chan, double scale)
{
	int x, y;
	double fx, fy;
	double nx, ny, nz;
	double v;
#ifndef C99
	double save;
#endif

	fftw_complex *imgspace1 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_complex *imgspace2 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_complex *freqspace1 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_complex *freqspace2 = fftw_malloc(w*h * sizeof(fftw_complex));
	fftw_plan i12f1 = fftw_plan_dft_2d(h, w, imgspace1, freqspace1, FFTW_FORWARD, FFTW_ESTIMATE);
	fftw_plan f12i1 = fftw_plan_dft_2d(h, w, freqspace1, imgspace1, FFTW_BACKWARD, FFTW_ESTIMATE);
	fftw_plan f22i2 = fftw_plan_dft_2d(h, w, freqspace2, imgspace2, FFTW_BACKWARD, FFTW_ESTIMATE);

	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
		switch(src_chan)
		{
			case 0:
			case 1:
			case 2:
			case 3:
				v = map[(w*y+x)*4+src_chan];
				break;
			case 4:
				v = (map[(w*y+x)*4+0] + map[(w*y+x)*4+1] + map[(w*y+x)*4+2]) / 3;
				break;
			default:
			case 5:
				v = (map[(w*y+x)*4+0]*0.114 + map[(w*y+x)*4+1]*0.587 + map[(w*y+x)*4+2]*0.299);
				break;
		}
#ifdef C99
		imgspace1[(w*y+x)] = (v - 128.0) / 127.0;
#else
		imgspace1[(w*y+x)][0] = (v - 128.0) / 127.0;
		imgspace1[(w*y+x)][1] = 0;
#endif
		if(v < 1)
			v = 1; /* do not write alpha zero */
		map[(w*y+x)*4+3] = floor(v + 0.5);
	}

	/* see http://www.gamedev.net/community/forums/topic.asp?topic_id=561430 */

	fftw_execute(i12f1);
	
	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
		fx = x;
		fy = y;
		if(fx > w/2)
			fx -= w;
		if(fy > h/2)
			fy -= h;
#ifdef DISCONTINUOUS
		fx = sin(fx * TWO_PI / w);
		fy = sin(fy * TWO_PI / h);
#else
#ifdef C99
		/* a lowpass to prevent the worst */
		freqspace1[(w*y+x)] *= 1 - pow(abs(fx) / (double)(w/2), 1);
		freqspace1[(w*y+x)] *= 1 - pow(abs(fy) / (double)(h/2), 1);
#else
		/* a lowpass to prevent the worst */
		freqspace1[(w*y+x)][0] *= 1 - pow(abs(fx) / (double)(w/2), 1);
		freqspace1[(w*y+x)][1] *= 1 - pow(abs(fx) / (double)(w/2), 1);
		freqspace1[(w*y+x)][0] *= 1 - pow(abs(fy) / (double)(h/2), 1);
		freqspace1[(w*y+x)][1] *= 1 - pow(abs(fy) / (double)(h/2), 1);
#endif
#endif
#ifdef C99
		freqspace2[(w*y+x)] = TWO_PI*_Complex_I * fy * freqspace1[(w*y+x)]; /* y derivative */
		freqspace1[(w*y+x)] = TWO_PI*_Complex_I * fx * freqspace1[(w*y+x)]; /* x derivative */
#else
		freqspace2[(w*y+x)][0] = -TWO_PI * fy * freqspace1[(w*y+x)][1]; /* y derivative */
		freqspace2[(w*y+x)][1] =  TWO_PI * fy * freqspace1[(w*y+x)][0];
		save = freqspace1[(w*y+x)][0];
		freqspace1[(w*y+x)][0] = -TWO_PI * fx * freqspace1[(w*y+x)][1]; /* x derivative */
		freqspace1[(w*y+x)][1] =  TWO_PI * fx * save;
#endif
	}

	fftw_execute(f12i1);
	fftw_execute(f22i2);

	scale /= (w*h);

	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
#ifdef C99
		nx = creal(imgspace1[(w*y+x)]);
		ny = creal(imgspace2[(w*y+x)]);
#else
		nx = imgspace1[(w*y+x)][0];
		ny = imgspace2[(w*y+x)][0];
#endif
		nx /= w;
		ny /= h;
		nz = -1 / scale;
		v = -sqrt(nx*nx + ny*ny + nz*nz);
		nx /= v;
		ny /= v;
		nz /= v;
		ny = -ny; /* DP inverted normals */
		map[(w*y+x)*4+2] = floor(128 + 127.5 * nx);
		map[(w*y+x)*4+1] = floor(128 + 127.5 * ny);
		map[(w*y+x)*4+0] = floor(128 + 127.5 * nz);
	}

	fftw_destroy_plan(i12f1);
	fftw_destroy_plan(f12i1);
	fftw_destroy_plan(f22i2);

	fftw_free(freqspace2);
	fftw_free(freqspace1);
	fftw_free(imgspace2);
	fftw_free(imgspace1);
}

void hmap_to_nmap_local(unsigned char *map, int w, int h, int src_chan, double scale, const double *filter, int filterw, int filterh)
{
	int x, y;
	double nx, ny, nz;
	double v;
	int i, j;
	double *img_reduced = malloc(w*h * sizeof(double));

	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
		switch(src_chan)
		{
			case 0:
			case 1:
			case 2:
			case 3:
				v = map[(w*y+x)*4+src_chan];
				break;
			case 4:
				v = (map[(w*y+x)*4+0] + map[(w*y+x)*4+1] + map[(w*y+x)*4+2]) / 3;
				break;
			default:
			case 5:
				v = (map[(w*y+x)*4+0]*0.114 + map[(w*y+x)*4+1]*0.587 + map[(w*y+x)*4+2]*0.299);
				break;
		}
		img_reduced[(w*y+x)] = (v - 128.0) / 127.0;
		if(v < 1)
			v = 1; /* do not write alpha zero */
		map[(w*y+x)*4+3] = floor(v + 0.5);
	}

	for(y = 0; y < h; ++y)
	for(x = 0; x < w; ++x)
	{
		nz = -1 / scale;
		nx = ny = 0;

		for(i = -filterh / 2; i <= filterh / 2; ++i)
			for(j = -filterw / 2; j <= filterw / 2; ++j)
			{
				nx += img_reduced[w*((y+i+h)%h)+(x+j+w)%w] * filter[(i + filterh / 2) * filterw + j + filterw / 2];
				ny += img_reduced[w*((y+j+h)%h)+(x+i+w)%w] * filter[(i + filterh / 2) * filterw + j + filterw / 2];
			}

		v = -sqrt(nx*nx + ny*ny + nz*nz);
		nx /= v;
		ny /= v;
		nz /= v;
		ny = -ny; /* DP inverted normals */
		map[(w*y+x)*4+2] = floor(128 + 127.5 * nx);
		map[(w*y+x)*4+1] = floor(128 + 127.5 * ny);
		map[(w*y+x)*4+0] = floor(128 + 127.5 * nz);
	}

	free(img_reduced);
}

unsigned char *FS_LoadFile(const char *fn, int *len)
{
	unsigned char *buf = NULL;
	int n;
	FILE *f = fopen(fn, "rb");
	*len = 0;
	if(!f)
		return NULL;
	for(;;)
	{
		buf = realloc(buf, *len + 65536);
		if(!buf)
		{
			fclose(f);
			free(buf);
			*len = 0;
			return NULL;
		}
		n = fread(buf + *len, 1, 65536, f);
		if(n < 0)
		{
			fclose(f);
			free(buf);
			*len = 0;
			return NULL;
		}
		*len += n;
		if(n < 65536)
			break;
	}
	return buf;
}

int FS_WriteFile(const char *fn, unsigned char *data, int len)
{
	FILE *f = fopen(fn, "wb");
	if(!f)
		return 0;
	if(fwrite(data, len, 1, f) != 1)
	{
		fclose(f);
		return 0;
	}
	if(fclose(f))
		return 0;
	return 1;
}

/* START stuff that originates from image.c in DarkPlaces */
int image_width, image_height;

typedef struct _TargaHeader
{
	unsigned char 	id_length, colormap_type, image_type;
	unsigned short	colormap_index, colormap_length;
	unsigned char	colormap_size;
	unsigned short	x_origin, y_origin, width, height;
	unsigned char	pixel_size, attributes;
}
TargaHeader;

void PrintTargaHeader(TargaHeader *t)
{
	printf("TargaHeader:\nuint8 id_length = %i;\nuint8 colormap_type = %i;\nuint8 image_type = %i;\nuint16 colormap_index = %i;\nuint16 colormap_length = %i;\nuint8 colormap_size = %i;\nuint16 x_origin = %i;\nuint16 y_origin = %i;\nuint16 width = %i;\nuint16 height = %i;\nuint8 pixel_size = %i;\nuint8 attributes = %i;\n", t->id_length, t->colormap_type, t->image_type, t->colormap_index, t->colormap_length, t->colormap_size, t->x_origin, t->y_origin, t->width, t->height, t->pixel_size, t->attributes);
}

unsigned char *LoadTGA_BGRA (const unsigned char *f, int filesize)
{
	int x, y, pix_inc, row_inci, runlen, alphabits;
	unsigned char *image_buffer;
	unsigned int *pixbufi;
	const unsigned char *fin, *enddata;
	TargaHeader targa_header;
	unsigned int palettei[256];
	union
	{
		unsigned int i;
		unsigned char b[4];
	}
	bgra;

	if (filesize < 19)
		return NULL;

	enddata = f + filesize;

	targa_header.id_length = f[0];
	targa_header.colormap_type = f[1];
	targa_header.image_type = f[2];

	targa_header.colormap_index = f[3] + f[4] * 256;
	targa_header.colormap_length = f[5] + f[6] * 256;
	targa_header.colormap_size = f[7];
	targa_header.x_origin = f[8] + f[9] * 256;
	targa_header.y_origin = f[10] + f[11] * 256;
	targa_header.width = image_width = f[12] + f[13] * 256;
	targa_header.height = image_height = f[14] + f[15] * 256;
	targa_header.pixel_size = f[16];
	targa_header.attributes = f[17];

	if (image_width > 32768 || image_height > 32768 || image_width <= 0 || image_height <= 0)
	{
		printf("LoadTGA: invalid size\n");
		PrintTargaHeader(&targa_header);
		return NULL;
	}

	/* advance to end of header */
	fin = f + 18;

	/* skip TARGA image comment (usually 0 bytes) */
	fin += targa_header.id_length;

	/* read/skip the colormap if present (note: according to the TARGA spec it */
	/* can be present even on 1color or greyscale images, just not used by */
	/* the image data) */
	if (targa_header.colormap_type)
	{
		if (targa_header.colormap_length > 256)
		{
			printf("LoadTGA: only up to 256 colormap_length supported\n");
			PrintTargaHeader(&targa_header);
			return NULL;
		}
		if (targa_header.colormap_index)
		{
			printf("LoadTGA: colormap_index not supported\n");
			PrintTargaHeader(&targa_header);
			return NULL;
		}
		if (targa_header.colormap_size == 24)
		{
			for (x = 0;x < targa_header.colormap_length;x++)
			{
				bgra.b[0] = *fin++;
				bgra.b[1] = *fin++;
				bgra.b[2] = *fin++;
				bgra.b[3] = 255;
				palettei[x] = bgra.i;
			}
		}
		else if (targa_header.colormap_size == 32)
		{
			memcpy(palettei, fin, targa_header.colormap_length*4);
			fin += targa_header.colormap_length * 4;
		}
		else
		{
			printf("LoadTGA: Only 32 and 24 bit colormap_size supported\n");
			PrintTargaHeader(&targa_header);
			return NULL;
		}
	}

	/* check our pixel_size restrictions according to image_type */
	switch (targa_header.image_type & ~8)
	{
	case 2:
		if (targa_header.pixel_size != 24 && targa_header.pixel_size != 32)
		{
			printf("LoadTGA: only 24bit and 32bit pixel sizes supported for type 2 and type 10 images\n");
			PrintTargaHeader(&targa_header);
			return NULL;
		}
		break;
	case 3:
		/* set up a palette to make the loader easier */
		for (x = 0;x < 256;x++)
		{
			bgra.b[0] = bgra.b[1] = bgra.b[2] = x;
			bgra.b[3] = 255;
			palettei[x] = bgra.i;
		}
		/* fall through to colormap case */
	case 1:
		if (targa_header.pixel_size != 8)
		{
			printf("LoadTGA: only 8bit pixel size for type 1, 3, 9, and 11 images supported\n");
			PrintTargaHeader(&targa_header);
			return NULL;
		}
		break;
	default:
		printf("LoadTGA: Only type 1, 2, 3, 9, 10, and 11 targa RGB images supported, image_type = %i\n", targa_header.image_type);
		PrintTargaHeader(&targa_header);
		return NULL;
	}

	if (targa_header.attributes & 0x10)
	{
		printf("LoadTGA: origin must be in top left or bottom left, top right and bottom right are not supported\n");
		return NULL;
	}

	/* number of attribute bits per pixel, we only support 0 or 8 */
	alphabits = targa_header.attributes & 0x0F;
	if (alphabits != 8 && alphabits != 0)
	{
		printf("LoadTGA: only 0 or 8 attribute (alpha) bits supported\n");
		return NULL;
	}

	image_buffer = (unsigned char *)malloc(image_width * image_height * 4);
	if (!image_buffer)
	{
		printf("LoadTGA: not enough memory for %i by %i image\n", image_width, image_height);
		return NULL;
	}

	/* If bit 5 of attributes isn't set, the image has been stored from bottom to top */
	if ((targa_header.attributes & 0x20) == 0)
	{
		pixbufi = (unsigned int*)image_buffer + (image_height - 1)*image_width;
		row_inci = -image_width*2;
	}
	else
	{
		pixbufi = (unsigned int*)image_buffer;
		row_inci = 0;
	}

	x = 0;
	y = 0;
	pix_inc = 1;
	if ((targa_header.image_type & ~8) == 2)
		pix_inc = (targa_header.pixel_size + 7) / 8;
	switch (targa_header.image_type)
	{
	case 1: /* colormapped, uncompressed */
	case 3: /* greyscale, uncompressed */
		if (fin + image_width * image_height * pix_inc > enddata)
			break;
		for (y = 0;y < image_height;y++, pixbufi += row_inci)
			for (x = 0;x < image_width;x++)
				*pixbufi++ = palettei[*fin++];
		break;
	case 2:
		/* BGR or BGRA, uncompressed */
		if (fin + image_width * image_height * pix_inc > enddata)
			break;
		if (targa_header.pixel_size == 32 && alphabits)
		{
			for (y = 0;y < image_height;y++)
				memcpy(pixbufi + y * (image_width + row_inci), fin + y * image_width * pix_inc, image_width*4);
		}
		else
		{
			for (y = 0;y < image_height;y++, pixbufi += row_inci)
			{
				for (x = 0;x < image_width;x++, fin += pix_inc)
				{
					bgra.b[0] = fin[0];
					bgra.b[1] = fin[1];
					bgra.b[2] = fin[2];
					bgra.b[3] = 255;
					*pixbufi++ = bgra.i;
				}
			}
		}
		break;
	case 9: /* colormapped, RLE */
	case 11: /* greyscale, RLE */
		for (y = 0;y < image_height;y++, pixbufi += row_inci)
		{
			for (x = 0;x < image_width;)
			{
				if (fin >= enddata)
					break; /* error - truncated file */
				runlen = *fin++;
				if (runlen & 0x80)
				{
					/* RLE - all pixels the same color */
					runlen += 1 - 0x80;
					if (fin + pix_inc > enddata)
						break; /* error - truncated file */
					if (x + runlen > image_width)
						break; /* error - line exceeds width */
					bgra.i = palettei[*fin++];
					for (;runlen--;x++)
						*pixbufi++ = bgra.i;
				}
				else
				{
					/* uncompressed - all pixels different color */
					runlen++;
					if (fin + pix_inc * runlen > enddata)
						break; /* error - truncated file */
					if (x + runlen > image_width)
						break; /* error - line exceeds width */
					for (;runlen--;x++)
						*pixbufi++ = palettei[*fin++];
				}
			}

			if (x != image_width)
			{
				/* pixbufi is useless now */
				printf("LoadTGA: corrupt file\n");
				break;
			}
		}
		break;
	case 10:
		/* BGR or BGRA, RLE */
		if (targa_header.pixel_size == 32 && alphabits)
		{
			for (y = 0;y < image_height;y++, pixbufi += row_inci)
			{
				for (x = 0;x < image_width;)
				{
					if (fin >= enddata)
						break; /* error - truncated file */
					runlen = *fin++;
					if (runlen & 0x80)
					{
						/* RLE - all pixels the same color */
						runlen += 1 - 0x80;
						if (fin + pix_inc > enddata)
							break; /* error - truncated file */
						if (x + runlen > image_width)
							break; /* error - line exceeds width */
						bgra.b[0] = fin[0];
						bgra.b[1] = fin[1];
						bgra.b[2] = fin[2];
						bgra.b[3] = fin[3];
						fin += pix_inc;
						for (;runlen--;x++)
							*pixbufi++ = bgra.i;
					}
					else
					{
						/* uncompressed - all pixels different color */
						runlen++;
						if (fin + pix_inc * runlen > enddata)
							break; /* error - truncated file */
						if (x + runlen > image_width)
							break; /* error - line exceeds width */
						for (;runlen--;x++)
						{
							bgra.b[0] = fin[0];
							bgra.b[1] = fin[1];
							bgra.b[2] = fin[2];
							bgra.b[3] = fin[3];
							fin += pix_inc;
							*pixbufi++ = bgra.i;
						}
					}
				}

				if (x != image_width)
				{
					/* pixbufi is useless now */
					printf("LoadTGA: corrupt file\n");
					break;
				}
			}
		}
		else
		{
			for (y = 0;y < image_height;y++, pixbufi += row_inci)
			{
				for (x = 0;x < image_width;)
				{
					if (fin >= enddata)
						break; /* error - truncated file */
					runlen = *fin++;
					if (runlen & 0x80)
					{
						/* RLE - all pixels the same color */
						runlen += 1 - 0x80;
						if (fin + pix_inc > enddata)
							break; /* error - truncated file */
						if (x + runlen > image_width)
							break; /* error - line exceeds width */
						bgra.b[0] = fin[0];
						bgra.b[1] = fin[1];
						bgra.b[2] = fin[2];
						bgra.b[3] = 255;
						fin += pix_inc;
						for (;runlen--;x++)
							*pixbufi++ = bgra.i;
					}
					else
					{
						/* uncompressed - all pixels different color */
						runlen++;
						if (fin + pix_inc * runlen > enddata)
							break; /* error - truncated file */
						if (x + runlen > image_width)
							break; /* error - line exceeds width */
						for (;runlen--;x++)
						{
							bgra.b[0] = fin[0];
							bgra.b[1] = fin[1];
							bgra.b[2] = fin[2];
							bgra.b[3] = 255;
							fin += pix_inc;
							*pixbufi++ = bgra.i;
						}
					}
				}

				if (x != image_width)
				{
					/* pixbufi is useless now */
					printf("LoadTGA: corrupt file\n");
					break;
				}
			}
		}
		break;
	default:
		/* unknown image_type */
		break;
	}

	return image_buffer;
}

int Image_WriteTGABGRA (const char *filename, int width, int height, const unsigned char *data)
{
	int y;
	unsigned char *buffer, *out;
	const unsigned char *in, *end;
	int ret;

	buffer = (unsigned char *)malloc(width*height*4 + 18);

	memset (buffer, 0, 18);
	buffer[2] = 2;		/* uncompressed type */
	buffer[12] = (width >> 0) & 0xFF;
	buffer[13] = (width >> 8) & 0xFF;
	buffer[14] = (height >> 0) & 0xFF;
	buffer[15] = (height >> 8) & 0xFF;

	for (y = 3;y < width*height*4;y += 4)
		if (data[y] < 255)
			break;

	if (y < width*height*4)
	{
		/* save the alpha channel */
		buffer[16] = 32;	/* pixel size */
		buffer[17] = 8; /* 8 bits of alpha */

		/* flip upside down */
		out = buffer + 18;
		for (y = height - 1;y >= 0;y--)
		{
			memcpy(out, data + y * width * 4, width * 4);
			out += width*4;
		}
	}
	else
	{
		/* save only the color channels */
		buffer[16] = 24;	/* pixel size */
		buffer[17] = 0; /* 8 bits of alpha */

		/* truncate bgra to bgr and flip upside down */
		out = buffer + 18;
		for (y = height - 1;y >= 0;y--)
		{
			in = data + y * width * 4;
			end = in + width * 4;
			for (;in < end;in += 4)
			{
				*out++ = in[0];
				*out++ = in[1];
				*out++ = in[2];
			}
		}
	}
	ret = FS_WriteFile (filename, buffer, out - buffer);

	free(buffer);

	return ret;
}
/* START stuff that originates from image.c in DarkPlaces */

int usage(const char *me)
{
	printf("Usage: %s <infile_norm.tga> <outfile_normandheight.tga> filtertype [<scale> [<offset> [<infile_ref.tga>]]] (get heightmap from normalmap)\n", me);
	printf("or:    %s <infile_height.tga> <outfile_normandheight.tga> filtertype -1 [<scale>] (read from B)\n", me);
	printf("or:    %s <infile_height.tga> <outfile_normandheight.tga> filtertype -2 [<scale>] (read from G)\n", me);
	printf("or:    %s <infile_height.tga> <outfile_normandheight.tga> filtertype -3 [<scale>] (read from R)\n", me);
	printf("or:    %s <infile_height.tga> <outfile_normandheight.tga> filtertype -4 [<scale>] (read from A)\n", me);
	printf("or:    %s <infile_height.tga> <outfile_normandheight.tga> filtertype -5 [<scale>] (read from (R+G+B)/3)\n", me);
	printf("or:    %s <infile_height.tga> <outfile_normandheight.tga> filtertype -6 [<scale>] (read from Y)\n", me);
	return 1;
}

static const double filter_scharr3[3][3] = {
	{  -3/32.0, 0,  3/32.0 },
	{ -10/32.0, 0, 10/32.0 },
	{  -3/32.0, 0,  3/32.0 }
};

static const double filter_prewitt3[3][3] = {
	{ -1/6.0, 0, 1/6.0 },
	{ -1/6.0, 0, 1/6.0 },
	{ -1/6.0, 0, 1/6.0 }
};

// pathologic for inverting
static const double filter_sobel3[3][3] = {
	{ -1/8.0, 0, 1/8.0 },
	{ -2/8.0, 0, 2/8.0 },
	{ -1/8.0, 0, 1/8.0 }
};

// pathologic for inverting
static const double filter_sobel5[5][5] = {
	{ -1/128.0,  -2/128.0, 0,  2/128.0, 1/128.0 },
	{ -4/128.0,  -8/128.0, 0,  8/128.0, 4/128.0 },
	{ -6/128.0, -12/128.0, 0, 12/128.0, 6/128.0 },
	{ -4/128.0,  -8/128.0, 0,  8/128.0, 4/128.0 },
	{ -1/128.0,  -2/128.0, 0,  2/128.0, 1/128.0 }
};

// pathologic for inverting
static const double filter_prewitt5[5][5] = {
	{ -1/40.0, -2/40.0, 0, 2/40.0, 1/40.0 },
	{ -1/40.0, -2/40.0, 0, 2/40.0, 1/40.0 },
	{ -1/40.0, -2/40.0, 0, 2/40.0, 1/40.0 },
	{ -1/40.0, -2/40.0, 0, 2/40.0, 1/40.0 },
	{ -1/40.0, -2/40.0, 0, 2/40.0, 1/40.0 }
};

static const double filter_trivial[1][3] = {
	{ -0.5, 0, 0.5 }
};

int main(int argc, char **argv)
{
	const char *infile, *outfile, *reffile;
	double scale, offset;
	int nmaplen, w, h;
	int renormalize = 0;
	double highpass = 0;
	unsigned char *nmapdata, *nmap, *refmap;
	const char *filtertype;
	const double *filter = NULL;
	int filterw = 0, filterh = 0;
#define USE_FILTER(f) \
	do \
	{ \
		filterw = sizeof(*(f)) / sizeof(**(f)); \
		filterh = sizeof((f)) / sizeof(*(f)); \
		filter = &(f)[0][0]; \
	} \
	while(0)

	if(argc > 1)
		infile = argv[1];
	else
		return usage(*argv);

	if(argc > 2)
		outfile = argv[2];
	else
		return usage(*argv);
	
	if(argc > 3)
		filtertype = argv[3];
	else
		return usage(*argv);
	
	if(argc > 4)
		scale = atof(argv[4]);
	else
		scale = 0;

	if(argc > 5)
		offset = atof(argv[5]);
	else
		offset = (scale<0) ? 1 : 0;

	if(argc > 6)
		reffile = argv[6];
	else
		reffile = NULL;

	if(getenv("FFT_NORMALMAP_TO_HEIGHTMAP_RENORMALIZE"))
		renormalize = atoi(getenv("FFT_NORMALMAP_TO_HEIGHTMAP_RENORMALIZE"));
	if(getenv("FFT_NORMALMAP_TO_HEIGHTMAP_HIGHPASS"))
		highpass = atof(getenv("FFT_NORMALMAP_TO_HEIGHTMAP_HIGHPASS"));

	nmapdata = FS_LoadFile(infile, &nmaplen);
	if(!nmapdata)
	{
		printf("FS_LoadFile failed\n");
		return 2;
	}
	nmap = LoadTGA_BGRA(nmapdata, nmaplen);
	free(nmapdata);
	if(!nmap)
	{
		printf("LoadTGA_BGRA failed\n");
		return 2;
	}
	w = image_width;
	h = image_height;

	if(reffile)
	{
		nmapdata = FS_LoadFile(reffile, &nmaplen);
		if(!nmapdata)
		{
			printf("FS_LoadFile failed\n");
			return 2;
		}
		refmap = LoadTGA_BGRA(nmapdata, nmaplen);
		free(nmapdata);
		if(!refmap)
		{
			printf("LoadTGA_BGRA failed\n");
			return 2;
		}
		if(image_width != w || image_height != h)
		{
			printf("reference map must have same size as input normalmap\n");
			return 2;
		}
	}
	else
		refmap = NULL;

	if(!strcmp(filtertype, "trivial"))
		USE_FILTER(filter_trivial);
	if(!strcmp(filtertype, "prewitt3"))
		USE_FILTER(filter_prewitt3);
	if(!strcmp(filtertype, "scharr3"))
		USE_FILTER(filter_scharr3);
	if(!strcmp(filtertype, "sobel3"))
		USE_FILTER(filter_sobel3);
	if(!strcmp(filtertype, "prewitt5"))
		USE_FILTER(filter_prewitt5);
	if(!strcmp(filtertype, "sobel5"))
		USE_FILTER(filter_sobel5);

	if(scale < 0)
	{
		if(filter)
			hmap_to_nmap_local(nmap, image_width, image_height, -scale-1, offset, filter, filterw, filterh);
		else
			hmap_to_nmap(nmap, image_width, image_height, -scale-1, offset);
	}
	else
		nmap_to_hmap(nmap, refmap, image_width, image_height, scale, offset, filter, filterw, filterh, renormalize, highpass);

	if(!Image_WriteTGABGRA(outfile, image_width, image_height, nmap))
	{
		printf("Image_WriteTGABGRA failed\n");
		free(nmap);
		return 2;
	}
	free(nmap);
	return 0;
}
