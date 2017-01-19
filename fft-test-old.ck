while (hop_size::samp => now) {
    (fft.upchuck().cval(hop_size * (read_offset.last() * read_center) $ int) $ polar).phase => float phase;
    buffer_id.push(phase);
    if (buffer_id.is_readable()) {
	buffer_id.read() => string id;
	if (id != "00" && contains(buffer_ids, id)) {	    
	    if (buffers[id].is_playable()) {
		<<< "play: ", id, "" >>>;
		spork ~ buffers[id].play(buffer_dur);
	    }
	}
	else if (id != "00") {
	    <<< "record: ", id, "" >>>;
	    LisaBuffer.create(buffer_dur, buffer_rate, buffer_gain) @=> buffers[id];
	    adc => buffers[id] => dac;
	    spork ~ buffers[id].record(buffer_dur);
	    buffer_ids << id;
	}
	buffer_id.reset();
    }
    if (count >= num_iters) {
	break;
    }
    //ifft.upchuck();
}
<<< "done", "" >>>;
