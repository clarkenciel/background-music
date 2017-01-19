adc => FFT fft =^ Centroid cent => blackhole; //IFFT ifft => Gain g => dac;
2048 => int fft_size => fft.size => Windowing.hann => fft.window => ifft.window;
fft_size / 4 => int hop_size;
g.gain(0.4);

class Message {
    string m_words[0];
    int m_write_head, m_size;
    string m_status;

    fun static Message create(int size) {
	return (new Message).init(size);
    }

    fun Message init(int size) {
	m_words.size(size);
	size => m_size;
	0 => m_write_head;
	"writing" => m_status;
	return this;
    }

    fun Message push(float word) {
	if (is_writable()) {
	    push_word(word);
	}
	return this;
    }

    fun string read() {
	"" => string output;
	for (int i; i < m_size; i++) {
	    m_words[i] +=> output;
	}
	return output;
    }

    fun int is_writable() {
	return m_status == "writing";
    }

    fun int is_readable() {
	return m_status == "done";
    }

    fun Message reset() {
	0 => m_write_head;
	"writing" => m_status;
	return this;
    }

    fun void push_word(float word) {
	process_word(word) => m_words[m_write_head];
	update_write_head();
    }

    fun void update_write_head() {
	1 +=> m_write_head;
	if (m_write_head == m_size) {
	    "done" => m_status;
	}
    }

    fun string process_word(float word) {
	(word + "") => string word_string;
	word_string.substring(0,1) == "-" ? 1 : 0 => int start_idx;
	word_string.substring(start_idx, 1) => string d1;
	word_string.substring(start_idx + 2, 1) => string d2;
	return d1 + d2;
    }
}

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
	duration * 0.2 => m_sampler.recRamp;
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
	duration * 0.2 => m_sampler.rampUp;
	1 => m_sampler.play;
	duration * 0.6 => now;
	duration * 0.2 => m_sampler.rampDown;
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
	return (new LBId).init(val);
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
    
    fun int matches(LBId) {
	return other.m_id == m_id;
    }

    fun int greater_than(LBId other) {
	if (other.m_id == m_id) {
	    return other.m_magnitude > m_magnitude;
	}
	else return 0;
    }

    fun int is_less_than_or_equal_to(LBid other) {
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
	return val.substring(start_index, dot_index);	
    }
}

class LBHolder {
    LisaBuffer m_buffers[0];
    LBid m_ids[0];
    float m_buf_rate, m_buf_gain;
    dur m_buf_dur;

    fun static LBHolder create(UGen in, UGen out,
			       int num_buffers, dur buf_dur, float buf_rate, float buf_gain) {
	return (new LBHolder).init(in, out, num_buffers, buf_dur, buf_rate, buf_gain);
    }

    fun LBHolder init(UGen in, UGen out, int num_buffers, dur buf_dur, float buf_rate, float buf_gain) {
	m_buffers.size(num_buffers);
	buf_dur => m_buf_dur;
	buf_rate => m_buf_rate;
	buf_gain => m_buf_gain;
	for (int i; i < num_buffers; i++) {
	    LisaBuffer.create(buf_dur, buf_rate, buf_gain) @=> m_buffers[i];
	    in => m_buffers[i] => out;
	}
	return this;
    }

    
    fun int should_overwrite(LBId id) {
	return has_buffer(id) && get_buffer_id(id).
	    is_less_than_or_equal_to(id);
    }

    fun int should_create_new(LBId id) {
	return does_not_have_buffer(id);
    }

    fun int should_play(LBId id) {
	return has_buffer(id);
    }

    fun void record_new(LBId id, dur record_length) {
	m_buffers[id.id()].record(record_length);
	m_ids << id;
    }

    fun void overwrite_sound(LBId id, dur record_length) {
	m_buffers[id.id()].record(record_length);
    }

    fun void play(LBId id, dur play_length) {
	m_buffers[id.id()].play(record_length);
    }

    fun LBid get_buffer_id(LBId to_match) {
	for (int i; i < m_ids.size()) {
	    if (m_ids[i].matches(to_match)) return m_ids[i];
	}
	return to_match;
    }

    fun int has_buffer(LBId id) {
	for (int i; i < m_ids.size(); i++) {
	    if (m_ids[i].matches(id)) return 1;
	}
	return 0;
    }
}

2 => int id_size;
10 => int num_iters;
0 => int count;
.76 => float buffer_rate;
0.8 => float buffer_gain;
5::second => dur buffer_dur;
10 => int num_bufs;

Message.create(id_size) @=> Message buffer_id;
LBHolder.create(adc, dac, num_bufs, buffer_dur, buffer_rate, buffer_gain) @=> LBHolder buffers;

<<< "begin", "" >>>;
complex fft_spectrum[];
LBId comparison_id;
second / samp => float srate;
while (hop_size::samp => now) {

    /* get the polar value of the centroid from the fft_bins. */
    cent.upchuck();
    fft.cvals() @=> fft_spectrum;
    cent.fval(0) => float bin_pos_f;
    (bin_pos_f * (fft_spectrum.size() / 2)) $ int => int fft_index;
    fft_spectrum[fft_index] $ polar => polar centroid_pol;
    bin_pos_f * srate / 2.0 => float centroid_freq;

    /* construct id */
    comparison_id.init(centroid_freq, centroid_pol.mag);

    /* check if record or overwrite or play */
    if (buffers.should_overwrite(comparison_id)) {
	buffers.overwite(comparison_id);
    }
    else if (buffers.should_create_new(comparison_id)) {
	buffers.record_new(comparison_id);
    }
    else if (buffers.should_play(comparison_id)) {
	buffers.play(comparison_id);
    }    
}

fun int contains(string coll[], string val) {
    for (int i; i < coll.size(); i++) {
	if (val == coll[i]) return 1;
    }
    return 0;
}
