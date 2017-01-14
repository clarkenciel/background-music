5 => int num_ffts;
FFT ffts[num_ffts];
IFFT iffts[num_ffts];
256 * 4 => int fft_size;
DelayL x => dac;
x => DelayL y => x;
second => x.max => y.max;
0.1::second => x.delay;
second => y.delay;
0.7 => y.gain;
0.5 => x.gain;

for (int i; i < num_ffts; i++) {
	adc => ffts[i] => blackhole;
	iffts[i] => x;
	fft_size => ffts[i].size;
	Windowing.blackmanHarris(fft_size) => ffts[i].window => iffts[i].window;
}
adc.gain(0.9);

true => int first;

//UAnaBlob new_blob, old_blob;
UAnaBlob new_blob[num_ffts];
UAnaBlob old_blob[num_ffts];

while (true) {
	for (int i; i < num_ffts; i++) {
		ffts[i].upchuck() @=> new_blob[i];
		if (first) {
			new_blob[i] @=> old_blob[i];
		}
		old_blob[i].cvals() @=> complex old_spectrum[];
		new_blob[i].cvals() @=> complex new_spectrum[];

		int first_pos, last_pos;
		old_spectrum.size() => int size;
		polar tmp_one, tmp_two, tmp_three;
		for (int i; i < size / 2; i++) {
			i => first_pos;
			size - 1 - i => last_pos;

			// convert to polar to reassign mags	
			old_spectrum[first_pos] $ polar @=> tmp_one;
			old_spectrum[last_pos] $ polar @=> tmp_two => tmp_three;
			tmp_one.mag => tmp_two.mag;
			tmp_three.mag => tmp_one.mag;
			tmp_two.phase - tmp_one.phase => tmp_one.phase;
			tmp_two $ complex => old_spectrum[first_pos];
			tmp_one $ complex => old_spectrum[last_pos];
		}
		if (!first) {
			new_blob[i] @=> old_blob[i];
		}

		iffts[i].transform(old_spectrum);
		(fft_size/num_ffts)::samp => now;
	}
	false => first;
} 

fun void copy_complex(complex one[], complex two[]) {
	one.size() => int size;
	for (int i; i < size; i++) {
		one[i] @=> two[i];
	}
}
