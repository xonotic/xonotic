#include <stdio.h>
#include <errno.h>
#include <stdarg.h>
#include <math.h>
#include "SDL/SDL.h" 
#include "SDL/SDL_ttf.h" 
#include "SDL/SDL_image.h" 

#ifdef _MSC_VER
#define snprintf _snprintf
#pragma message("You are using a broken and outdated compiler. Do not expect this to work.")
#endif

void warn(const char *fmt, ...)
{
	va_list list;
	int e = errno;
	va_start(list, fmt);
	vfprintf(stderr, fmt, list);
	fputs(": ", stderr);
	fputs(strerror(e), stderr);
	fputs("\n", stderr);
}

void warnx(const char *fmt, ...)
{
	va_list list;
	va_start(list, fmt);
	vfprintf(stderr, fmt, list);
	fputs("\n", stderr);
}

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

void Image_WriteTGABGRA (const char *filename, int width, int height, const unsigned char *data)
{
    int y;
    unsigned char *buffer, *out;
    const unsigned char *in, *end;
	FILE *f;

    buffer = (unsigned char *)malloc(width*height*4 + 18);

    memset (buffer, 0, 18);
    buffer[2] = 2;      /*  uncompressed type */
    buffer[12] = (width >> 0) & 0xFF;
    buffer[13] = (width >> 8) & 0xFF;
    buffer[14] = (height >> 0) & 0xFF;
    buffer[15] = (height >> 8) & 0xFF;

    for (y = 3;y < width*height*4;y += 4)
        if (data[y] < 255)
            break;

    if (y < width*height*4)
    {   
        /*  save the alpha channel */
        buffer[16] = 32;    /*  pixel size */
        buffer[17] = 8; /*  8 bits of alpha */

        /*  flip upside down */
        out = buffer + 18;
        for (y = height - 1;y >= 0;y--)
        {   
            memcpy(out, data + y * width * 4, width * 4);
            out += width*4;
        }
    }
    else
    {   
        /*  save only the color channels */
        buffer[16] = 24;    /*  pixel size */
        buffer[17] = 0; /*  8 bits of alpha */

        /*  truncate bgra to bgr and flip upside down */
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

	f = fopen(filename, "wb");
	if(!f)
		err(1, "WriteTGA");
	if(fwrite(buffer, out - buffer, 1, f) != 1)
		err(1, "WriteTGA");
	if(fclose(f))
		err(1, "WriteTGA");

    free(buffer);
}

/*
 * Return the pixel value at (x, y)
 * NOTE: The surface must be locked before calling this!
 */
Uint32 getpixel(SDL_Surface *surface, int x, int y)
{
    int bpp = surface->format->BytesPerPixel;
    /* Here p is the address to the pixel we want to retrieve */
    Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + x * bpp;

    switch(bpp) {
    case 1:
        return *p;

    case 2:
        return *(Uint16 *)p;

    case 3:
        if(SDL_BYTEORDER == SDL_BIG_ENDIAN)
            return p[0] << 16 | p[1] << 8 | p[2];
        else
            return p[0] | p[1] << 8 | p[2] << 16;

    case 4:
        return *(Uint32 *)p;

    default:
        return 0;       /* shouldn't happen, but avoids warnings */
    }
}

/*
 * Set the pixel at (x, y) to the given value
 * NOTE: The surface must be locked before calling this!
 */
void putpixel(SDL_Surface *surface, int x, int y, Uint32 pixel)
{
    int bpp = surface->format->BytesPerPixel;
    /* Here p is the address to the pixel we want to set */
    Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + x * bpp;

    switch(bpp) {
    case 1:
        *p = pixel;
        break;

    case 2:
        *(Uint16 *)p = pixel;
        break;

    case 3:
        if(SDL_BYTEORDER == SDL_BIG_ENDIAN) {
            p[0] = (pixel >> 16) & 0xff;
            p[1] = (pixel >> 8) & 0xff;
            p[2] = pixel & 0xff;
        } else {
            p[0] = pixel & 0xff;
            p[1] = (pixel >> 8) & 0xff;
            p[2] = (pixel >> 16) & 0xff;
        }
        break;

    case 4:
        *(Uint32 *)p = pixel;
        break;
    }
}

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))
#define BOUND(a,b,c) MAX(a,MIN(b,c))
#define BLURFUNC(d,A,B) A-B*(d)
#define BLURFUNCIMAX(A,B) ceil(sqrt((A)/(B)))

Uint32 getpixelfilter(SDL_Surface *src, SDL_PixelFormat *fmt, int x, int y, double A, double B, double C)
{
	double r, g, b, a, f;
	Uint8 pr, pg, pb, pa;
	int i, j;
	int imax = (int) BLURFUNCIMAX(A,B);

	/*  1. calculate blackened blurred image */
	a = 0;
	for(i=-imax; i<=imax; ++i)
		if(y+i >= 0 && y+i < src->h)
			for(j=-imax; j<=imax; ++j)
				if(x+j >= 0 && x+j < src->w)
				{
					SDL_GetRGBA(getpixel(src, x+j, y+i), src->format, &pr, &pg, &pb, &pa);
					f = BLURFUNC(i*i+j*j, A, B);
					f = MAX(0, f);

					if(C == 0)
						a = MAX(a, pa * f);
					else
						a = a + pa * f;
				}
	a = MIN(a, 255);

	if(C == 0)
	{
		/*  2. overlap it with the actual image again */
		if(y >= 0 && y < src->h && x >= 0 && x < src->w)
		{
			SDL_GetRGBA(getpixel(src, x, y), src->format, &pr, &pg, &pb, &pa);

			f = a + pa - (a * pa) / 255L;

			r = pr * pa / f;
			g = pg * pa / f;
			b = pb * pa / f;

			a = f;
		}
		else
		{
			r = 0;
			g = 0;
			b = 0;
			a = a;
		}
	}
	else if(C > 0)
		r = g = b = MAX(0, 255 - C * (255 - a));
	else if(C < 0)
		r = g = b = MAX(0, 255 + C * a);

	return SDL_MapRGBA(fmt, (unsigned char) r, (unsigned char) g, (unsigned char) b, (unsigned char) a);
}

void blitfilter(SDL_Surface *src, SDL_Surface *dest, int x0, int y0, double A, double B, double C)
{
	/*  note: x0, y0 is the origin of the UNFILTERED image; it is "transparently" expanded by a BLURFUNCIMAX. */
	int x, y, d, xa, ya, xb, yb;
	d = (int) BLURFUNCIMAX(A, B);

	SDL_LockSurface(src);
	SDL_LockSurface(dest);

	xa = x0 - d;
	ya = y0 - d;
	xb = x0 + src->w + d;
	yb = y0 + src->h + d;

	if(xa < 0) xa = 0;
	if(ya < 0) ya = 0;
	if(xa >= dest->w) xa = dest->w - 1;
	if(ya >= dest->h) ya = dest->h - 1;
	for(y = ya; y <= yb; ++y)
		for(x = xa; x <= xb; ++x)
			putpixel(dest, x, y, getpixelfilter(src, dest->format, x - x0, y - y0, A, B, C));
	SDL_UnlockSurface(dest);
	SDL_UnlockSurface(src);
}

int mapFont(int d, char *c_)
{
	unsigned char *c = (unsigned char *) c_;
	if(!d)
		return ((*c >= 0x20 && *c <= 0x7E) || (*c >= 0xA0 && *c <= 0xFE)) ? 0 : -1;
	if(*c >= 0x20 && *c <= 0x7E)
		return 0;
	if(*c >= 0xA0 && *c <= 0xAF)
	{
		*c &= 0x7F;
		return 1;
	}
	if(*c >= 0xB0 && *c <= 0xB9)
	{
		*c &= 0x7F;
		return 2;
	}
	if(*c >= 0xBA && *c <= 0xDF)
	{
		*c &= 0x7F;
		return 1; /*  cool */
	}
	if(*c >= 0xE0 && *c <= 0xFE)
	{
		*c &= 0x5F;
		return 2; /*  lcd */
	}
	return -1;
}

/**
 * @brief Blit a surface onto another and stretch it.
 * With a 4.2 gcc you can use -fopenmp :)
 * You might want to add some linear fading for scaling up?
 *
 * @param dst Destination surface
 * @param src Source surface, if NULL, the destination surface is used
 * @param drec The target area
 * @param srec The source area, if NULL, then you suck :P
 */
void StretchBlit(SDL_Surface *dst, SDL_Surface *src, SDL_Rect *drec, SDL_Rect *srec)
{
	unsigned int freeSource;
	int x, y;
	double scaleX;
	double scaleY;
	

	if(!src)
		src = dst;

	freeSource = 0;
	if(src == dst) {
		/*  To avoid copying copied pixels, that would suck :) */
		src = SDL_ConvertSurface(dst, dst->format, dst->flags);
		freeSource = 1;
	}

	if(!drec)
		drec = &dst->clip_rect;
	if(!srec)
		srec = &src->clip_rect;

	SDL_LockSurface(dst);
	SDL_LockSurface(src);

	scaleX = (double)srec->w / (double)drec->w;
	scaleY = (double)srec->h / (double)drec->h;
	
	for(y = drec->y; y < (drec->y + drec->h); ++y)
	{
		int dy;
		if(y >= dst->h)
			break;
		dy = y - drec->y;
		for(x = drec->x; x < (drec->x + drec->w); ++x)
		{
			int dx;
			double dfromX, dfromY, dtoX, dtoY;
			int fromX, fromY, toX, toY;
			int i, j;
			unsigned int r, g, b, a, ar, ag, ab;
			unsigned int count;

			if(x >= dst->w)
				break;
			/*  dx, dy relative to the drec start */
			dx = x - drec->x;

			/*  Get the pixel range which represents the current pixel */
			/*  When scaling down this should be a rectangle :) */
			/*  Otherwise it's just 1 pixel anyway, from==to then */
			dfromX = dx * scaleX;
			dfromY = dy * scaleY;
			dtoX = (dx+1) * scaleX;
			dtoY = (dy+1) * scaleY;
			/*  The first and last one usually aren't 100% within this space */
			fromX = (int)dfromX; dfromX = 1.0 - (dfromX - fromX); /*  invert the from percentage */
			fromY = (int)dfromY; dfromY = 1.0 - (dfromY - fromY);
			toX = (int)dtoX; dtoX -= toX; /*  this one is ok */
			toY = (int)dtoY; dtoY -= toY;
						
			/* Short explanation:
			 * FROM is where to START, so when it's 5.7, then 30% of the 5th pixel is to be used
			 * TO is where it ENDS, so if it's 8.4, then 40% of the 9th pixel is to be used!
			 */
						
			/*  Now get all the pixels and merge them together... */
			count = 0;
			r = g = b = a = ar = ag = ab = 0;
			/*if(drec->w > 1024)
			  printf("%i %i - %f %f\n", fromX, toX, dfromX, dtoX);*/

			/*  when going from one to the next there's usually one */
			/*  situation where the left pixel has a value of 0.1something and */
			/*  the right one of 0 */
			/*  so adjust the values here */
			/*  otherwise we get lines in the image with the original color */
			/*  of the left pixel */
			if(toX - fromX == 1 && drec->w > srec->w) {
				dfromX = 1.0 - dtoX;
				++fromX;
			}
			if(fromX == toX) {
				dfromX -= 0.5;
				if(dfromX > 0.0) {
					--fromX;
					dtoX = 1.0-dfromX;
				} else {
					++toX;
					dtoX = -dfromX;
					dfromX = 1.0-dtoX;
				}
			}
			if(toY - fromY == 1 && drec->h > srec->h) {
				dfromY = 1.0 - dtoY;
				++fromY;
			}
			if(fromY == toY) {
				dfromY -= 0.5;
				if(dfromY > 0.0) {
					--fromY;
					dtoY = 1.0-dfromY;
				} else {
					++toY;
					dtoY = -dfromY;
					dfromY = 1.0-dtoY;
				}
			}
			for(j = fromY; j <= toY; ++j)
			{
				if(j < 0)
					continue;
				if((j+srec->y) >= src->h)
					break;
				for(i = fromX; i <= toX; ++i)
				{
					Uint8 pr, pg, pb, pa;
					Uint16 par, pag, pab;
					double inc = 1;
					int iinc;
					if(x < 0)
						continue;
					if((i+srec->x) >= src->w)
						break;

					SDL_GetRGBA(getpixel(src, i + srec->x, j + srec->y), src->format, &pr, &pg, &pb, &pa);
					par = pa * (unsigned int)pr;
					pag = pa * (unsigned int)pg;
					pab = pa * (unsigned int)pb;

					if(i == fromX)
						inc *= dfromX;
					if(j == fromY)
						inc *= dfromY;
					if(i == (toX))
						inc *= dtoX;
					if(j == (toY))
						inc *= dtoY;

					iinc = (int) (inc * 256);

					r += (pr * iinc);
					g += (pg * iinc);
					b += (pb * iinc);
					ar += (par * iinc);
					ag += (pag * iinc);
					ab += (pab * iinc);
					a += (pa * iinc);
					/* ++count; */
					count += iinc;
				}
			}
			/* printf("COLOR VALUE: %i, %i, %i, %i \t COUNT: %f\n", r, g, b, a, count); */
			if(a)
			{
				r = ar / a;
				g = ag / a;
				b = ab / a;
				a /= count;
			}
			else
			{
				r /= count;
				g /= count;
				b /= count;
				a /= count;
			}

			putpixel(dst, x, y, SDL_MapRGBA(dst->format, (Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a));
		}
	}
	
	SDL_UnlockSurface(dst);
	SDL_UnlockSurface(src);

	if(freeSource)
		SDL_FreeSurface(src);
}

void StretchDown(SDL_Surface *srfc, int x, int y, int w, int h, int wtarget)
{
	/*  @"#$ SDL has no StretchBlit */
	/*  this one is slow, but at least I know how it works */
	int r, c;
	unsigned int *stretchedline = (unsigned int *) alloca(8 * wtarget * sizeof(unsigned int)); /*  ra ga ba r g b a n */
	SDL_LockSurface(srfc);

	for(r = y; r < y + h; ++r)
	{
		/*  each input pixel is wtarget pixels "worth" */
		/* memset(stretchedline, sizeof(stretchedline), 0); */
		memset(stretchedline, 0, 8 * wtarget * sizeof(unsigned int));
		for(c = 0; c < w * wtarget; ++c)
		{
			Uint8 pr, pg, pb, pa;
			unsigned int *p = &stretchedline[8 * (c / w)];
			SDL_GetRGBA(getpixel(srfc, x + c / wtarget, r), srfc->format, &pr, &pg, &pb, &pa);
			p[0] += (unsigned int) pr * (unsigned int) pa;
			p[1] += (unsigned int) pg * (unsigned int) pa;
			p[2] += (unsigned int) pb * (unsigned int) pa;
			p[3] += (unsigned int) pr;
			p[4] += (unsigned int) pg;
			p[5] += (unsigned int) pb;
			p[6] += (unsigned int) pa;
			p[7] += 1;
		}
		for(c = 0; c < wtarget; ++c)
		{
			unsigned int *p = &stretchedline[8 * c];
			if(p[6])
				putpixel(srfc, x + c, r, SDL_MapRGBA(srfc->format, p[0] / p[6], p[1] / p[6], p[2] / p[6], p[6] / p[7]));
			else
				putpixel(srfc, x + c, r, SDL_MapRGBA(srfc->format, p[3] / p[7], p[4] / p[7], p[5] / p[7], p[6] / p[7]));
		}
		for(c = wtarget; c < w; ++c)
			putpixel(srfc, x + c, r, SDL_MapRGBA(srfc->format, 0, 0, 0, 0));
	}

	SDL_UnlockSurface(srfc);
}

int GetBoundingBox(SDL_Surface *surf, const SDL_Rect *inbox, SDL_Rect *outbox)
{
	int bx = -1, by = -1; /*  start */
	/* int bw = 0, bh = 0; */
	int ex = -1, ey = -1; /*  end */
	int cx, cy;
	for(cx = inbox->x; cx < inbox->x + inbox->w; ++cx)
	{
		for(cy = inbox->y; cy < inbox->y + inbox->h; ++cy)
		{
			Uint8 pr, pg, pb, pa;
			SDL_GetRGBA(getpixel(surf, cx, cy), surf->format, &pr, &pg, &pb, &pa);
			/*  include colors, or only care about pa? */
			if(!pa)
				continue;

			if(bx < 0) {
				bx = ex = cx;
				by = ey = cy;
				continue;
			}
			
			if(cx < bx) /*  a pixel more on the left */
				bx = cx;
			if(cy < by) /*  a pixel more above... */
			    by = cy;
			if(cx > ex) /*  a pixel on the right */
				ex = cx;
			if(cy > ey) /*  a pixel on the bottom :) */
				ey = cy;
		}
	}

	if(ex < 0)
		return 0;

	outbox->x = bx;
	outbox->y = by;
	outbox->w = (ex - bx + 1);
	outbox->h = (ey - by + 1);
	return 1;
}

int main(int argc, char **argv)
{
	SDL_Rect in, out;
	SDL_Surface *conchars, *conchars0;
	SDL_Surface *glyph;
	TTF_Font *fonts[3];
	SDL_Color white = {255, 255, 255, 255};
	Uint32 transparent;
	int maxAscent, maxDescent, maxWidth;
	int i, j;
	int currentSize;
	int isfixed;
	const char *infilename;
	int referenceTop;
	int referenceBottom;
	int cell;
	const char *outfilename;
	const char *font0;
	const char *font1;
	const char *font2;
	double A;
	double B;
	double C;
	int differentFonts;
	int d;
	double f = 0, a = 0;
	char widthfilename[512];
	int border;
	FILE *widthfile;

	if(argc != 12)
		errx(1, "Usage: %s infile.tga topref bottomref cellheight outfile.tga font.ttf fontCOOL.ttf fontLCD.ttf blurA blurB blurColors\n", argv[0]);

	infilename = argv[1];
	referenceTop = atoi(argv[2]);
	referenceBottom = atoi(argv[3]);
	cell = atoi(argv[4]);
	outfilename = argv[5];
	font0 = argv[6];
	font1 = argv[7];
	font2 = argv[8];
	A = atof(argv[9]);
	B = atof(argv[10]);
	C = atof(argv[11]);

	d = (int) BLURFUNCIMAX(1, B);
	fprintf(stderr, "Translating parameters:\nA=%f B=%f (using %d pixels)\n", A, B, (int) BLURFUNCIMAX(1, B));
	if(C == 0)
	{
		B = A * B;
		A = A * 1;
	}
	else
	{
		for(i=-d; i<=d; ++i)
			for(j=-d; j<=d; ++j)
			{
				f = BLURFUNC(i*i+j*j, 1, B);
				f = MAX(0, f);

				if(C == 0)
					a = MAX(a, f);
				else
					a = a + f;
			}
		B = A/a * B;
		A = A/a * 1;
	}
	fprintf(stderr, "A=%f B=%f (using %d pixels)\n", A, B, (int) BLURFUNCIMAX(A, B));

	snprintf(widthfilename, sizeof(widthfilename), "%.*s.width", (int)strlen(outfilename) - 4, outfilename);

	border=(int) BLURFUNCIMAX(A, B);

	if(SDL_Init(0) < 0)
		errx(1, "SDL_Init failed");

	if(TTF_Init() < 0)
		errx(1, "TTF_Init failed: %s", TTF_GetError());

	conchars0 = IMG_Load(infilename);
	if(!conchars0)
		errx(1, "IMG_Load failed: %s", IMG_GetError());

	if(conchars0->w != conchars0->h)
		errx(1, "conchars aren't square");
	if(conchars0->w % 16)
		errx(1, "conchars have bad width");
	
	conchars = SDL_CreateRGBSurface(SDL_SWSURFACE, cell * 16, cell * 16, 32, 0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000);
	in.x = in.y = out.x = out.y = 0;
	in.w = in.h = conchars0->w;
	out.w = out.h = cell * 16;
	StretchBlit(conchars, conchars0, &out, &in);
	SDL_FreeSurface(conchars0);

	for(currentSize = cell * 2; currentSize; --currentSize)
	{
		fonts[0] = TTF_OpenFont(font0, currentSize);
		if(!fonts[0])
			errx(1, "TTF_OpenFont %s failed: %s", font0, TTF_GetError());

		if(strcmp(font0, font1) || strcmp(font0, font2))
		{
			if(*font1)
			{
				fonts[1] = TTF_OpenFont(font1, currentSize);
				if(!fonts[1])
					warnx("TTF_OpenFont %s failed: %s", font1, TTF_GetError());
			}
			else
				fonts[1] = NULL;

			if(*font2)
			{
				fonts[2] = TTF_OpenFont(font2, currentSize);
				if(!fonts[2])
					warnx("TTF_OpenFont %s failed: %s", font2, TTF_GetError());
			}
			else
				fonts[2] = NULL;

			differentFonts = 1;
		}
		else
		{
			fonts[1] = fonts[2] = fonts[0];
			differentFonts = 0;
		}

		/* maxAscent = MAX(MAX(TTF_FontAscent(fonts[0]), fonts[1] ? TTF_FontAscent(fonts[1]) : 0), fonts[2] ? TTF_FontAscent(fonts[2]) : 0); */
		/* maxDescent = -MIN(MIN(TTF_FontDescent(fonts[0]), fonts[1] ? TTF_FontDescent(fonts[1]) : 0), fonts[2] ? TTF_FontDescent(fonts[2]) : 0); */
		maxAscent = 0;
		maxDescent = 0;
		maxWidth = 0;
		for(i = 0; i < 256; ++i)
		{
			char str[2];
			int fntid = mapFont(differentFonts, &str[0]);
			str[0] = i; str[1] = 0;
			if(fntid < 0)
				continue;
			if(!fonts[fntid])
				continue;
			glyph = TTF_RenderText_Blended(fonts[fntid], str, white);
			if(!glyph)
				errx(1, "TTF_RenderText_Blended %d failed: %s", i, TTF_GetError());
			if(fntid == 0)
				maxWidth = MAX(maxWidth, glyph->w);

			in.x = 0;
			in.y = 0;
			in.w = glyph->w;
			in.h = glyph->h;
			if(GetBoundingBox(glyph, &in, &out))
			{
				int baseline = TTF_FontAscent(fonts[fntid]);
				int asc = baseline - out.y;
				int desc = (out.y + out.h - 1) - baseline;
				//fprintf(stderr, "%c: rect %d %d %d %d baseline %d\n", (int)i, out.x, out.y, out.w, out.h, baseline);
				//fprintf(stderr, "%c: ascent %d descent %d\n", (int)i, asc, desc);
				if(asc > maxAscent)
					maxAscent = asc;
				if(desc > maxDescent)
					maxDescent = desc;
			}

			SDL_FreeSurface(glyph);
		}

		maxAscent += 10;
		maxDescent += 10;

		if(border + maxAscent + 1 + maxDescent + border <= cell)
			if(border + maxWidth + border <= cell)
				break; /*  YEAH */

		if(differentFonts)
		{
			if(fonts[2])
				TTF_CloseFont(fonts[2]);
			if(fonts[1])
				TTF_CloseFont(fonts[1]);
		}
		TTF_CloseFont(fonts[0]);
	}
	if(!currentSize)
		errx(1, "Sorry, no suitable size found.");
	fprintf(stderr, "Using font size %d (%d + 1 + %d)\n", currentSize, maxAscent, maxDescent);

	isfixed = TTF_FontFaceIsFixedWidth(fonts[0]);
	if(getenv("FORCE_FIXED"))
		isfixed = 1;

	/*  TODO convert conchars to BGRA (so the TGA writer can reliably use it) */

	transparent = SDL_MapRGBA(conchars->format, 255, 0, 255, 0);

	widthfile = fopen(widthfilename, "w");
	if(!widthfile)
		err(1, "fopen widthfile");
	fprintf(widthfile, "extraspacing %f\n", 0.0);
	fprintf(widthfile, "scale %f\n", 1.0);

	for(i = 0; i < 256; ++i)
	{
		int w, h;
		int fntid;
		SDL_Rect dest;
		char str[2]; str[0] = i; str[1] = 0;

		if(i && !(i % 16))
			fprintf(widthfile, "\n");

		fntid = mapFont(differentFonts, &str[0]);
		if(fntid < 0 || !fonts[fntid])
		{
			SDL_Rect src, src2;
			int destTop, destBottom;

			src.x = cell * (i % 16);
			src.y = cell * (i / 16);
			src.w = cell;
			src.h = cell;
			src2.x = 0;
			src2.y = 0;
			src2.w = cell;
			src2.h = cell;
			glyph = SDL_CreateRGBSurface(SDL_SWSURFACE, cell, cell, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
			SDL_FillRect(glyph, &src2, transparent);

			/*  map: */
			/*    referenceTop    -> (cell - (maxAscent + 1 + maxDescent)) / 2 */
			/*    referenceBottom -> (cell - (maxAscent + 1 + maxDescent)) / 2 + maxAscent */

			destTop = (cell - (maxAscent + 1 + maxDescent)) / 2;
			destBottom = (cell - (maxAscent + 1 + maxDescent)) / 2 + maxAscent;

			/*  map is: */
			/*    x' = x / cell * h + y */
			/*  solve: */
			/*    destTop = referenceTop / cell * h + y */
			/*    destBottom = referenceBottom / cell * h + y */

			dest.x = 0;
			dest.y = (int) ((double) (destBottom * referenceTop - destTop * referenceBottom) / (double) (referenceTop - referenceBottom));
			dest.h = (int) (cell * (double) (destBottom - destTop) / (double) (referenceBottom - referenceTop));
			dest.w = dest.h;

			/*
			if(dest.y < 0)
				dest.y = 0;
			if(dest.w > glyph->w)
				dest.w = glyph->w;
			if(dest.y + dest.h > glyph->h)
				dest.h = glyph->h - dest.y;
			*/

			if(isfixed)
				dest.w = border + maxWidth + border;
			StretchBlit(glyph, conchars, &dest, &src);
			/* SDL_FillRect(conchars, &src, transparent); */
			/* SDL_BlitSurface(glyph, &src2, conchars, &src); */
			StretchBlit(conchars, glyph, &src, &src2);
			SDL_FreeSurface(glyph);
			fprintf(widthfile, "%f ", dest.w / (double) cell);
			continue;
		}

		fprintf(stderr, "glyph %d...\n", i);

		glyph = TTF_RenderText_Blended(fonts[fntid], str, white);
		if(!glyph)
			errx(1, "TTF_RenderText_Blended %d failed: %s", i, TTF_GetError());

		w = border + glyph->w + border;
		h = border + glyph->h + border;
		if(w > cell)
			warnx("sorry, this font contains a character that is too wide... output will be borked");

		dest.x = cell * (i % 16);
		dest.y = cell * (i / 16);
		dest.w = cell;
		dest.h = cell;
		SDL_FillRect(conchars, &dest, transparent);

		dest.x += border + (isfixed ? ((border + maxWidth + border - w) / 2) : 0);
		dest.y += (cell - (maxAscent + 1 + maxDescent)) / 2 + (maxAscent - TTF_FontAscent(fonts[fntid]));
		blitfilter(glyph, conchars, dest.x, dest.y, A, B, C);

		SDL_FreeSurface(glyph);

		if(isfixed && w > border + maxWidth + border)
		{
			StretchDown(conchars, cell * (i % 16), cell * (i / 16), w, cell, border + maxWidth + border);
			fprintf(widthfile, "%f ", (border + maxWidth + border) / (double) cell);
		}
		else
			fprintf(widthfile, "%f ", (isfixed ? border + maxWidth + border : w) / (double) cell);
	}

	fprintf(widthfile, "\n");
	fclose(widthfile);

	fprintf(stderr, "Writing...\n");

	Image_WriteTGABGRA(outfilename, conchars->w, conchars->h, (unsigned char *) conchars->pixels);

	SDL_FreeSurface(conchars);

	SDL_Quit();

	return 0;
}
