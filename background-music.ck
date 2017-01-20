adc => FFT fft =^ Centroid cent => blackhole; //IFFT ifft => Gain g => dac;
2048 => int fft_size => fft.size => Windowing.hann => fft.window;
adc => Gain g => dac;
fft_size / 4 => int hop_size;
g.gain(0.1);

class LisaBuffer extends Chubgraph {
    inlet => LiSa m_sampler => Gain m_gain => outlet;
    string m_status;

    fun static LisaBuffer create(dur duration, float rate, float gain) {
	return (new LisaBuffer).init(duration, rate, gain);
    }
    
    fun LisaBuffer init(dur duration, float rate, float gain) {
	duration => m_sampler.duration;
	gain => m_gain.gain;
	rate => m_sampler.rate;
	"created" => m_status;
	duration => m_sampler.recRamp;
	return this;
    }

    fun LisaBuffer record(dur duration) {
	"recording" => m_status;
	0::ms => m_sampler.recPos;
	1 => m_sampler.record;
	duration => now;
	0 => m_sampler.record;
	"playable" => m_status;
    }

    fun LisaBuffer play(dur duration) {
	"playing" => m_status;
	0::ms => m_sampler.playPos;
	duration * 0.3 => m_sampler.rampUp;
	1 => m_sampler.play;
	duration * 0.4 => now;
	duration * 0.3 => m_sampler.rampDown;
	0 => m_sampler.play;
	"playable" => m_status;
    }

    fun int is_playable() {
	return m_status == "playable";
    }
}

class LBId {
    float m_magnitude;
    string m_id;

    fun static LBId from_freq_mag(float freq, float mag) {
	return (new LBId).init(freq, mag);
    }

    fun static LBId from_zero() {
	return (new LBId).init(0.0, 0.0);
    }

    fun LBId init(float freq, float mag) {
	mag => m_magnitude;
	create_id(freq) => m_id;
	return this;
    }

    fun string id() {
	return m_id;
    }
    
    fun int matches(LBId other) {
	return other.m_id == m_id;
    }

    fun int greater_than(LBId other) {
	if (other.m_id == m_id) {
	    return other.m_magnitude > m_magnitude;
	}
	else return 0;
    }

    fun int is_less_than_or_equal_to(LBId other) {
	if (other.m_id == m_id) {
	    return other.m_magnitude <= m_magnitude;
	}
	else return 0;
    }

    fun string create_id(float val) {
	(val + "") => string val_string;
	val_string.find('.') => int dot_index;
	val_string.find('-') => int dash_index;
	dash_index > 0 ? dash_index : 0 => int start_index;
	return val_string.substring(start_index+1, 2);
    }

    fun void print() {
	chout <= m_id <= " " <= m_magnitude <= "\n";
    }
}

class LBHolder {
    LisaBuffer m_buffers[0];
    LBId m_ids[0];
    int m_id_buffer_index[0];
    float m_buf_rate, m_buf_gain;
    dur m_buf_dur;
    0 => int m_current_write_index;
    int m_max;

    fun static LBHolder create(UGen in, UGen out,
			       int num_buffers, dur buf_dur, float buf_rate, float buf_gain) {
	return (new LBHolder).init(in, out, num_buffers, buf_dur, buf_rate, buf_gain);
    }

    fun LBHolder init(UGen in, UGen out, int num_buffers, dur buf_dur, float buf_rate, float buf_gain) {
	num_buffers => m_buffers.size => m_id_buffer_index.size;
	buf_dur => m_buf_dur;
	buf_rate => m_buf_rate;
	buf_gain => m_buf_gain;
	num_buffers => m_max;
	for (int i; i < num_buffers; i++) {
	    LisaBuffer.create(buf_dur, buf_rate, buf_gain) @=> m_buffers[i];
	    in => m_buffers[i] => out;
	}
	return this;
    }

    
    fun int should_overwrite(LBId id) {
	if (has_buffer(id)) {
	    get_buffer_id(id) @=> LBId compare;
	    if (compare.is_less_than_or_equal_to(id) &&
		Math.random2f(0.0, 0.7) > Math.random2f(0.6, 1.0)) {
		return 1;
	    }
	    else return 0;
	}
	else return 0;
    }

    fun int should_create_new(LBId id) {
	if (m_current_write_index < m_max && Math.random2f(0.0, 0.7) > Math.random2f(0.65, 1.0)) {
	    return does_not_have_buffer(id);
	}
	else return 0;
    }

    fun int should_play(LBId id) {
	return has_buffer(id) && Math.random2f(0.0, 0.7) > Math.random2f(0.5, 1.0);
    }

    fun void record_new(LBId id, dur record_length) {
	add_new_buffer(id);
	get_buffer(id).record(record_length);
    }

    fun void overwrite(LBId id, dur record_length) {
	get_buffer(id).record(record_length);
    }

    fun void play(LBId id, dur play_length) {
	get_buffer(id).play(play_length);
    }

    fun LBId get_buffer_id(LBId to_match) {
	for (int i; i < m_ids.size(); i++) {
	    if (m_ids[i].matches(to_match)) return m_ids[i];
	}
	return to_match;
    }

    fun LisaBuffer get_buffer(LBId id) {
	return m_buffers[m_id_buffer_index[id.id()]];
    }

    fun int has_buffer(LBId id) {
	for (int i; i < m_ids.size(); i++) {
	    if (m_ids[i].matches(id)) return 1;
	}
	return 0;
    }

    fun int does_not_have_buffer(LBId id) {
	return !has_buffer(id);
    }

    fun void add_new_buffer(LBId id) {
	m_current_write_index => m_id_buffer_index[id.id()];
	m_ids << id;
	m_current_write_index++;
    }

    fun void print_ids() {
	for (int i; i < m_ids.size(); i++) {
	    m_ids[i].print();
	}
    }
}

2 => int id_size;
10 => int num_iters;
0 => int count;
1.0 => float buffer_rate;
0.8 => float buffer_gain;
5::second => dur buffer_dur;
10 => int num_bufs;

LBHolder.create(adc, dac, num_bufs, buffer_dur, buffer_rate, buffer_gain) @=> LBHolder buffers;

<<< "begin", "" >>>;
complex fft_spectrum[];

second / samp => float srate;
LBId comparison_id;
while (hop_size::samp => now) {

    /* get the polar value of the centroid from the fft_bins. */
    cent.upchuck();
    fft.cvals() @=> fft_spectrum;
    cent.fval(0) => float bin_pos_f;
    (bin_pos_f * (fft_spectrum.size() / 2)) $ int => int fft_index;
    fft_spectrum[fft_index] $ polar => polar centroid_pol;
    bin_pos_f * srate / 2.0 => float centroid_freq;

    /* construct id */
    LBId.from_freq_mag(centroid_freq, centroid_pol.mag) @=> comparison_id;

    /* check if record or overwrite or play */
    // buffers.print_ids();
    if (buffers.should_overwrite(comparison_id)) {
	<<< "overwriting: ", comparison_id.id(), "" >>>;
	spork ~ buffers.overwrite(comparison_id, buffer_dur);
    }
    else if (buffers.should_create_new(comparison_id)) {
	<<< "creating new: ", comparison_id.id(), "" >>>;
	spork ~ buffers.record_new(comparison_id, buffer_dur);
    }
    else if (buffers.should_play(comparison_id)) {
	<<< "playing: ", comparison_id.id(), "" >>>;
	spork ~ buffers.play(comparison_id, buffer_dur);
    }
}
