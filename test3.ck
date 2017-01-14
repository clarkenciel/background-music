adc => FFT fft =^ IFFT ifft => dac;

10::second + now => time end;
while (now < end) {
	ifft.upchuck();
	fft.size()::samp => now;
}

