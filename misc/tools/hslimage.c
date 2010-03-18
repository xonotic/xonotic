#include <math.h>
#include <stdio.h>

#define MARGIN_X 0
#define MARGIN_Y 0

void hsl_to_rgb(float hsl_x, float hsl_y, float hsl_z, float *rgb_x, float *rgb_y, float *rgb_z)
{
	float mi, ma, maminusmi, h;

	if(hsl_z <= 0.5)
		maminusmi = hsl_y * 2 * hsl_z;
	else
		maminusmi = hsl_y * (2 - 2 * hsl_z);
	
	// hsl_z     = 0.5 * mi + 0.5 * ma
	// maminusmi =     - mi +       ma
	mi = hsl_z - 0.5 * maminusmi;
	ma = hsl_z + 0.5 * maminusmi;

	h = hsl_x - 6 * floor(hsl_x / 6);

	//else if(ma == rgb_x)
	//	h = 60 * (rgb_y - rgb_z) / (ma - mi);
	if(h <= 1)
	{
		*rgb_x = ma;
		*rgb_y = h * (ma - mi) + mi;
		*rgb_z = mi;
	}
	//else if(ma == rgb_y)
	//	h = 60 * (rgb_z - rgb_x) / (ma - mi) + 120;
	else if(h <= 2)
	{
		*rgb_x = (2 - h) * (ma - mi) + mi;
		*rgb_y = ma;
		*rgb_z = mi;
	}
	else if(h <= 3)
	{
		*rgb_x = mi;
		*rgb_y = ma;
		*rgb_z = (h - 2) * (ma - mi) + mi;
	}
	//else // if(ma == rgb_z)
	//	h = 60 * (rgb_x - rgb_y) / (ma - mi) + 240;
	else if(h <= 4)
	{
		*rgb_x = mi;
		*rgb_y = (4 - h) * (ma - mi) + mi;
		*rgb_z = ma;
	}
	else if(h <= 5)
	{
		*rgb_x = (h - 4) * (ma - mi) + mi;
		*rgb_y = mi;
		*rgb_z = ma;
	}
	//else if(ma == rgb_x)
	//	h = 60 * (rgb_y - rgb_z) / (ma - mi);
	else // if(h <= 6)
	{
		*rgb_x = ma;
		*rgb_y = mi;
		*rgb_z = (6 - h) * (ma - mi) + mi;
	}
}

void hslimage_color(float v_x, float v_y, float margin_x, float margin_y, float *rgb_x, float *rgb_y, float *rgb_z)
{
	v_x = (v_x - margin_x) / (1 - 2 * margin_x);
	v_y = (v_y - margin_y) / (1 - 2 * margin_y);
	if(v_x < 0) v_x = 0;
	if(v_y < 0) v_y = 0;
	if(v_x > 1) v_x = 1;
	if(v_y > 1) v_y = 1;
	if(v_y > 0.875) // grey bar
		hsl_to_rgb(0, 0, v_x, rgb_x, rgb_y, rgb_z);
	else
		hsl_to_rgb(v_x * 6, 1, (v_y / 0.875), rgb_x, rgb_y, rgb_z);
}

int main()
{
	int x, y;
	float r, g, b;

	for(y = 0; y < 512; ++y)
	{
		for(x = 0; x < 512; ++x)
		{
			hslimage_color(x / 512.0, y / 512.0, MARGIN_X, MARGIN_Y, &r, &g, &b);
			/*
			putc(floor(r * 15 + 0.5) * 17, stdout);
			putc(floor(g * 15 + 0.5) * 17, stdout);
			putc(floor(b * 15 + 0.5) * 17, stdout);
			*/
			putc(floor(r * 255 + 0.5), stdout);
			putc(floor(g * 255 + 0.5), stdout);
			putc(floor(b * 255 + 0.5), stdout);
		}
	}
	return 0;
}
