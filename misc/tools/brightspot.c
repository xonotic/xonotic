#include <stdio.h>
#include <math.h>

// USAGE: see brightspot.sh (and in the future brightspot.bat)
// It should output the right parameters for the sun direction in q3map2's format.
// But probably is broken.

#define false 0
#define true 1

int flip[6*3] =
{
	false, false,  true, // "rt"
	 true,  true,  true, // "lf"
	false,  true, false, // "bk"
	 true, false, false, // "ft"
	false, false,  true, // "up"
	false, false,  true  // "dn"
};

static const double skyboxtexcoord2f[6*4*2] =
{
    // skyside[0]
    0, 1,
    1, 1,
    1, 0,
    0, 0,
    // skyside[1]
    1, 0,
    0, 0,
    0, 1,
    1, 1,
    // skyside[2]
    1, 1,
    1, 0,
    0, 0,
    0, 1,
    // skyside[3]
    0, 0,
    0, 1,
    1, 1,
    1, 0,
    // skyside[4]
    0, 1,
    1, 1,
    1, 0,
    0, 0,
    // skyside[5]
    0, 1,
    1, 1,
    1, 0,
    0, 0
};


static const double skyboxvertex3f[6*4*3] =
{
        // skyside[0]
         16, -16,  16,
         16, -16, -16,
         16,  16, -16,
         16,  16,  16,
        // skyside[1]
        -16,  16,  16,
        -16,  16, -16,
        -16, -16, -16,
        -16, -16,  16,
        // skyside[2]
         16,  16,  16,
         16,  16, -16,
        -16,  16, -16,
        -16,  16,  16,
        // skyside[3]
        -16, -16,  16,
        -16, -16, -16,
         16, -16, -16,
         16, -16,  16,
        // skyside[4]
        -16, -16,  16,
         16, -16,  16,
         16,  16,  16,
        -16,  16,  16,
        // skyside[5]
         16, -16, -16,
        -16, -16, -16,
        -16,  16, -16,
         16,  16, -16
};

void Unmap2f(double x, double y, const double *corners, double *u, double *v)
{
	// x - corners[0] == *u * (corners[2] - corners[0]) + *v * (corners[4] - corners[2]);
	// y - corners[1] == *u * (corners[3] - corners[1]) + *v * (corners[5] - corners[3]);
	
	double xc0 = x - corners[0];
	double yc1 = y - corners[1];
	double c20 = corners[2] - corners[0];
	double c31 = corners[3] - corners[1];
	double c42 = corners[4] - corners[2];
	double c53 = corners[5] - corners[3];

	// xc0 == *u * c20 + *v * c42;
	// yc1 == *u * c31 + *v * c53;

	double det = c20 * c53 - c31 * c42;
	double du = xc0 * c53 - yc1 * c42;
	double dv = c20 * yc1 - c31 * xc0;

	*u = du / det;
	*v = dv / det;
}

void Map3f(double u, double v, const double *corners, double *x, double *y, double *z)
{
	*x = corners[0] + u * (corners[3] - corners[0]) + v * (corners[6] - corners[3]);
	*y = corners[1] + u * (corners[4] - corners[1]) + v * (corners[7] - corners[4]);
	*z = corners[2] + u * (corners[5] - corners[2]) + v * (corners[8] - corners[5]);
}

void MapCoord(int pic, int y, int x, double vec[3])
{
	int h;
	int flipx = flip[3*pic+0];
	int flipy = flip[3*pic+1];
	int flipdiag = flip[3*pic+2];
	double u, v;

	if(flipx)
		x = 511 - x;

	if(flipy)
		y = 511 - y;

	if(flipdiag)
	{
		h = x; x = y; y = h;
	}

	Unmap2f((x + 0.5) / 512.0, (y + 0.5) / 512.0, skyboxtexcoord2f + 4*2*pic, &u, &v);
	Map3f(u, v, skyboxvertex3f + 6*2*pic, &vec[0], &vec[1], &vec[2]);
}

int main(int argc, char **argv)
{
	FILE *f;
	int i, j, k;
	unsigned char picture[6][512][512];
	unsigned char max;
	double brightvec[3];
	double pitch, yaw, l;

	if(argc != 2)
	{
		fprintf(stderr, "Usage: %s imagefile.gray\n", *argv);
		return 1;
	}

	f = fopen(argv[1], "rb");
	if(!f)
	{
		perror("fopen");
		return 1;
	}
	fread(&picture, sizeof(picture), 1, f);
	fclose(f);

	brightvec[0] = brightvec[1] = brightvec[2] = 0;
	max = 0;
	for(i = 0; i < 6; ++i)
		for(j = 0; j < 512; ++j)
			for(k = 0; k < 512; ++k)
				if(picture[i][j][k] > max)
					max = picture[i][j][k];
	for(i = 0; i < 6; ++i)
		for(j = 0; j < 512; ++j)
			for(k = 0; k < 512; ++k)
			{
				double vec[3], f;
				MapCoord(i, j, k, vec);
				f = pow(vec[0]*vec[0] + vec[1]*vec[1] + vec[2]*vec[2], -1.5); // I know what I am doing.
				f *= exp(10 * (picture[i][j][k] - max));
				brightvec[0] += f * vec[0];
				brightvec[1] += f * vec[1];
				brightvec[2] += f * vec[2];
			}

	l = sqrt(brightvec[0]*brightvec[0] + brightvec[1]*brightvec[1] + brightvec[2]*brightvec[2]);
	fprintf(stderr, "vec = %f %f %f\n", brightvec[0] / l, brightvec[1] / l, brightvec[2] / l);
	
	pitch = atan2(brightvec[2], sqrt(brightvec[0]*brightvec[0] + brightvec[1]*brightvec[1]));
	yaw = atan2(brightvec[1], brightvec[0]);

	printf("%f %f\n", yaw * 180 / M_PI, pitch * 180 / M_PI);
	return 0;
}
