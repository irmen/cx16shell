%import strings
%import diskio
%import floats
%import shellroutines
%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000

main {
    %option force_output
    str music_filename = "?"*40
    uword vera_rate_hz
    ubyte vera_rate

    const ubyte FT_WAV = 1
    const ubyte FT_ZSM = 2

    sub start() {
        uword colors = shell.get_text_colors()
        shell.txt_color(shell.TXT_COLOR_HIGHLIGHT)
        shell.print("WAV/ZSM/ZCM sound player for Commander X16.\n")
        shell.txt_color(shell.TXT_COLOR_HIGHLIGHT_PROMPT)
        shell.print("Supports ZSMs/ZCMs and uncompressed or IMA-ADPCM WAVs.\n\n")
        shell.txt_color(shell.TXT_COLOR_NORMAL)

        cx16.get_program_args(music_filename, len(music_filename), false)
        if music_filename[0]==0 {
            error("Missing arguments: filename")
        }

        if strings.endswith(music_filename, ".wav") or strings.endswith(music_filename, ".WAV") {
            prepare_wav()
            shell.chrout('\n')
            shell.print("Playing, press STOP to abort. ")
            interrupts_wav.set_handler()
            play_wav()
            interrupts_wav.clear_handler()
            shell.chrout('\n')
        }
        else if strings.endswith(music_filename, ".zsm") or strings.endswith(music_filename, ".ZSM") {
            load_zsm_or_zcm()
    		shell.print("Playing, press STOP to abort. ")
    		zsmkit2.zsmkit_setisr()
		    zsmkit2.play_music()
    		zsmkit2.zsmkit_clearisr()
        }
        else if strings.endswith(music_filename, ".zcm") or strings.endswith(music_filename, ".ZCM") {
            load_zsm_or_zcm()
            print_zcm_info()
            shell.chrout('\n')
    		shell.print("Playing, press STOP to abort. ")
    		zsmkit2.zsmkit_setisr()
		    zsmkit2.play_digi()
    		zsmkit2.zsmkit_clearisr()
        }
        else
            error("Invalid file extension")

        sys.exit(0)
    }

    sub error(str msg) {
        shell.err_set(msg)
        sys.exit(1)
    }

    sub load_zsm_or_zcm() {
        ; first load zsmkit player blob
        if not zsmkit2.load_zsmkit()
            error("error loading zsmkit2")
        zsmkit2.zsm_init_engine(&zsmkit2.zsmkit_lowram)

        shell.txt_color(shell.TXT_COLOR_HIGHLIGHT_PROMPT)
        shell.print("Loading ")
        shell.print(music_filename)
        shell.chrout('\n')
        shell.txt_color(shell.TXT_COLOR_NORMAL)
        cx16.rambank(zsmkit2.ZSMKitBank+1)
        if diskio.load_raw(music_filename, $A000)==0
            error("load error")
        cx16.rambank(zsmkit2.ZSMKitBank+1)
    }

    sub print_zcm_info() {
        ^^zsmkit2.ZCMHeader header = $a000
        long size = mklong2(header.size_hi as uword, header.size_lo)
        ubyte bits = if header.vera_cfg & (1 << 5)!=0 then 16 else 8
        ubyte channels = if header.vera_cfg & (1 << 4)!=0 then 2 else 1
        ubyte volume = header.vera_cfg & 15
        shell.print("     size: ")
        shell.print_l(size)
        shell.print("\n     rate: ")
        float rate = header.vera_rate as float * main.calculate_vera_rate.vera_freq_factor
        shell.print_uw(rate as uword)
        shell.print("\n     bits: ")
        shell.print_ub(bits)
        shell.print("\n channels: ")
        shell.print_ub(channels)
        shell.print("\n   volume: ")
        shell.print_ub(volume)
        float bytes_per_sample = bits as float / 8.0
        float duration = size as float / (channels as float) / rate / bytes_per_sample
        shell.print("\n duration: ")
        shell.print_uw(duration as uword)
        shell.print(" seconds\n")
    }

    sub prepare_wav() {
        shell.txt_color(shell.TXT_COLOR_HIGHLIGHT_PROMPT)
        shell.print("Checking ")
        shell.print(music_filename)
        shell.chrout('\n')
        shell.txt_color(shell.TXT_COLOR_NORMAL)

        bool wav_ok = false
        if diskio.f_open(music_filename) {
            void diskio.f_read(music.buffer, 128)
            wav_ok = wavfile.parse_header(music.buffer)
            diskio.f_close()
        }
        if not wav_ok
            error("no good wav file!")

        calculate_vera_rate()

        shell.print("           format: ")
        shell.print_ub(wavfile.wavefmt)
        shell.print("\n         channels: ")
        shell.print_ub(wavfile.nchannels)
        shell.print("\n      sample rate: ")
        shell.print_uw(wavfile.sample_rate)
        shell.print(" Hz\n        vera rate: ")
        shell.print_ub(vera_rate)
        shell.print(" = ")
        shell.print_uw(vera_rate_hz)
        shell.print(" Hz\n  bits per sample: ")
        shell.print_uw(wavfile.bits_per_sample)
        if wavfile.wavefmt==wavfile.WAVE_FORMAT_DVI_ADPCM {
            shell.print("\n adpcm block size: ")
            shell.print_uw(wavfile.block_align)
        }
        float bytes_per_sample = wavfile.bits_per_sample as float / 8.0
        float duration = wavfile.data_size as float / (wavfile.nchannels as float) / (wavfile.sample_rate as float) / bytes_per_sample
        shell.print("\n         duration: ")
        cx16.r0 = duration as uword
        if wavfile.wavefmt==wavfile.WAVE_FORMAT_DVI_ADPCM
            cx16.r0 *= 4    ; adpcm is 1:4 compression
        shell.print_uw(cx16.r0)
        shell.print(" seconds\n")

        if wavfile.nchannels>2 or
           (wavfile.wavefmt!=wavfile.WAVE_FORMAT_DVI_ADPCM and wavfile.wavefmt!=wavfile.WAVE_FORMAT_PCM) or
           wavfile.sample_rate > 48828 or
           wavfile.bits_per_sample>16
                error("unsupported format!")

        if wavfile.wavefmt==wavfile.WAVE_FORMAT_DVI_ADPCM {
            if(wavfile.block_align!=256) {
                error("unsupported block alignment!")
            }
        }

        cx16.VERA_AUDIO_RATE = 0                ; halt playback
        cx16.VERA_AUDIO_CTRL = %10101011        ; mono 16 bit, volume 11
        if wavfile.nchannels==2
            cx16.VERA_AUDIO_CTRL = %10111011    ; stereo 16 bit, volume 11
        if(wavfile.bits_per_sample==8)
            cx16.VERA_AUDIO_CTRL &= %11011111    ; set to 8 bit instead
        repeat 1024
            cx16.VERA_AUDIO_DATA = 0            ; fill buffer with short silence
    }

    sub calculate_vera_rate() {
        const float vera_freq_factor = 25e6 / 65536.0
        vera_rate = (wavfile.sample_rate as float / vera_freq_factor) + 1.0 as ubyte
        vera_rate_hz = (vera_rate as float) * vera_freq_factor as uword
    }

    sub play_wav() {
        str progress = "|/-\\"

        if diskio.f_open(music_filename) {
            uword block_size = 1024
            if wavfile.wavefmt==wavfile.WAVE_FORMAT_DVI_ADPCM
                block_size = wavfile.block_align * 2      ; read 2 adpcm blocks at a time (512 bytes)
            void diskio.f_read(music.buffer, wavfile.data_offset)       ; skip to actual sample data start
            music.pre_buffer(block_size)
            cx16.VERA_AUDIO_RATE = vera_rate    ; start audio playback
            ubyte progress_count
            repeat {
                interrupts_wav.wait()
                if interrupts_wav.aflow {
                    interrupts_wav.aflow=false
                    if not music.load_next_block(block_size)
                        break
                    ; Note: copying the samples into the fifo buffer is done by the aflow interrupt handler itself.

                    shell.chrout(progress[progress_count])
                    shell.chrout(157)       ; cursor left
                    progress_count = (progress_count+1) & 3

                    void cbm.STOP()
                    if_z {
                        interrupts_wav.clear_handler()
                        shell.print(" \nbreak\n")
                        break
                    }
                }
            }

            diskio.f_close()
            shell.chrout(' ')
        } else {
            error("load error")
        }

        cx16.VERA_AUDIO_RATE = 0                ; halt playback
    }
}


interrupts_wav {
    uword system_irq
    ubyte system_ien

    sub set_handler() {
        sys.set_irqd()
        system_irq = cbm.CINV
        cbm.CINV = &handler          ; irq handler for AFLOW
        system_ien = cx16.VERA_IEN
        cx16.VERA_IEN = %00001001    ; enable AFLOW and VSYNC
        sys.clear_irqd()
    }

    sub clear_handler() {
        sys.set_irqd()
        cbm.CINV = system_irq
        cx16.VERA_IEN = 1
        sys.clear_irqd()
    }

    bool aflow
    uword idle_counter

    sub wait() {
        ; NOTE: should be doing a WAI instruction here to wait for the next AFLOW irq
        ; but we want to gather "idle time" counter statistics.
        idle_counter = 0
        while not aflow {
            idle_counter++
        }
    }

    sub handler() {
        if cx16.VERA_ISR & %00001000 !=0 {
            ; Filling the fifo is the only way to clear the Aflow irq.
            ; So we do this here, otherwise the aflow irq will keep triggering.
            ; Note that filling the buffer with fresh audio samples is NOT done here,
            ; but instead in the main program code that triggers on the 'aflow' being true!
            cx16.save_virtual_registers()
            music.aflow_play_block()
            cx16.restore_virtual_registers()
            aflow = true

            %asm {{
                ply
                plx
                pla
                rti
            }}
        }

        goto system_irq
    }

}

music {
    long disk_read_bytes
    long pcm_fifo_bytes

    uword @requirezp nibblesptr
    uword buffer = memory("buffer", 1024, 256)

    sub pre_buffer(uword block_size) {
        ; pre-buffer first block
        disk_read_bytes = diskio.f_read(buffer, block_size)
    }

    sub aflow_play_block() {
        ; play block that is currently in the buffer
        if wavfile.wavefmt==wavfile.WAVE_FORMAT_DVI_ADPCM {
            nibblesptr = buffer
            if wavfile.nchannels==2 {
                adpcm_block_stereo()
                adpcm_block_stereo()
                music.pcm_fifo_bytes += 996 * 2
            }
            else {
                adpcm_block_mono()
                adpcm_block_mono()
                music.pcm_fifo_bytes += 1010 * 2
            }
        }
        else if wavfile.bits_per_sample==16 {
            uncompressed_block_16()
            music.pcm_fifo_bytes += 1024
        }
        else {
            uncompressed_block_8()
            music.pcm_fifo_bytes += 1024
        }
    }

    sub load_next_block(uword block_size) -> bool {
        ; read next block from disk into the buffer, for next time the irq triggers
        disk_read_bytes += block_size
        return diskio.f_read(buffer, block_size) == block_size
    }

    asmsub uncompressed_block_8() {
        ; copy 1024 bytes of audio data from the buffer into vera's fifo, quickly!
        ; converting unsigned wav 8 bit samples to signed 8 bit on the fly.
        %asm {{
            lda  p8v_buffer
            sta  _loop+1
            sta  _lp2+1
            lda  p8v_buffer+1
            sta  _loop+2
            sta  _lp2+2
            ldx  #4
            ldy  #0
_loop       lda  $ffff,y    ;modified
            eor  #$80       ; convert to signed
            sta  cx16.VERA_AUDIO_DATA
            iny
_lp2        lda  $ffff,y    ; modified
            eor  #$80       ; convert to signed
            sta  cx16.VERA_AUDIO_DATA
            iny
            bne  _loop
            inc  _loop+2
            inc  _lp2+2
            dex
            bne  _loop
            rts
        }}

; original prog8 code:
;        uword @requirezp ptr = main.start.buffer
;        ubyte @requirezp sample
;        repeat 1024 {
;            sample = @(ptr) - 128
;            cx16.VERA_AUDIO_DATA = sample
;            ptr++
;        }
    }

    asmsub uncompressed_block_16() {
        ; copy 1024 bytes of audio data from the buffer into vera's fifo, quickly!
        %asm {{
            lda  p8v_buffer
            sta  _loop+1
            sta  _lp2+1
            lda  p8v_buffer+1
            sta  _loop+2
            sta  _lp2+2
            ldx  #4
            ldy  #0
_loop       lda  $ffff,y    ; modified
            sta  cx16.VERA_AUDIO_DATA
            iny
_lp2        lda  $ffff,y    ; modified
            sta  cx16.VERA_AUDIO_DATA
            iny
            bne  _loop
            inc  _loop+2
            inc  _lp2+2
            dex
            bne  _loop
            rts
        }}
; original prog8 code:
;        uword @requirezp ptr = main.start.buffer
;        repeat 1024 {
;            cx16.VERA_AUDIO_DATA = @(ptr)
;            ptr++
;        }
    }

    sub adpcm_block_mono() {
        ; refill the fifo buffer with one decoded adpcm block (1010 bytes of pcm data)
        adpcm.init(peekw(nibblesptr), @(nibblesptr+2))
        cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
        cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
        nibblesptr += 4
        ubyte @zp nibble
        repeat 252/2 {
            unroll 2 {
                nibble = @(nibblesptr)
                ; note: when calling decode_nibble(), the upper nibble in the argument needs to be zero
                adpcm.decode_nibble(nibble & 15)     ; first word
                cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
                cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
                adpcm.decode_nibble(nibble>>4)       ; second word
                cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
                cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
                nibblesptr++
            }
        }
    }

    sub adpcm_block_stereo() {
        ; refill the fifo buffer with one decoded adpcm block (996 bytes of pcm data)
        adpcm.init(peekw(nibblesptr), @(nibblesptr+2))            ; left channel
        cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
        cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
        adpcm.init_second(peekw(nibblesptr+4), @(nibblesptr+6))   ; right channel
        cx16.VERA_AUDIO_DATA = lsb(adpcm.predict_2)
        cx16.VERA_AUDIO_DATA = msb(adpcm.predict_2)
        nibblesptr += 8
        repeat 248/8
            decode_nibbles_unrolled()
    }

    sub decode_nibbles_unrolled() {
        ; decode 4 left channel nibbles
        ; note: when calling decode_nibble(), the upper nibble in the argument needs to be zero
        uword[8] left
        uword[8] right
        ubyte @requirezp nibble = @(nibblesptr)
        adpcm.decode_nibble(nibble & 15)     ; first word
        left[0] = adpcm.predict
        adpcm.decode_nibble(nibble>>4)       ; second word
        left[1] = adpcm.predict
        nibble = @(nibblesptr+1)
        adpcm.decode_nibble(nibble & 15)     ; first word
        left[2] = adpcm.predict
        adpcm.decode_nibble(nibble>>4)       ; second word
        left[3] = adpcm.predict
        nibble = @(nibblesptr+2)
        adpcm.decode_nibble(nibble & 15)     ; first word
        left[4] = adpcm.predict
        adpcm.decode_nibble(nibble>>4)       ; second word
        left[5] = adpcm.predict
        nibble = @(nibblesptr+3)
        adpcm.decode_nibble(nibble & 15)     ; first word
        left[6] = adpcm.predict
        adpcm.decode_nibble(nibble>>4)       ; second word
        left[7] = adpcm.predict

        ; decode 4 right channel nibbles
        nibble = @(nibblesptr+4)
        adpcm.decode_nibble_second(nibble & 15)     ; first word
        right[0] = adpcm.predict_2
        adpcm.decode_nibble_second(nibble>>4)       ; second word
        right[1] = adpcm.predict_2
        nibble = @(nibblesptr+5)
        adpcm.decode_nibble_second(nibble & 15)     ; first word
        right[2] = adpcm.predict_2
        adpcm.decode_nibble_second(nibble>>4)       ; second word
        right[3] = adpcm.predict_2
        nibble = @(nibblesptr+6)
        adpcm.decode_nibble_second(nibble & 15)     ; first word
        right[4] = adpcm.predict_2
        adpcm.decode_nibble_second(nibble>>4)       ; second word
        right[5] = adpcm.predict_2
        nibble = @(nibblesptr+7)
        adpcm.decode_nibble_second(nibble & 15)     ; first word
        right[6] = adpcm.predict_2
        adpcm.decode_nibble_second(nibble>>4)       ; second word
        right[7] = adpcm.predict_2
        nibblesptr += 8

        %asm {{
            ; copy to vera PSG fifo buffer
            ldy  #0
-           lda  p8v_left_lsb,y
            sta  cx16.VERA_AUDIO_DATA
            lda  p8v_left_msb,y
            sta  cx16.VERA_AUDIO_DATA
            lda  p8v_right_lsb,y
            sta  cx16.VERA_AUDIO_DATA
            lda  p8v_right_msb,y
            sta  cx16.VERA_AUDIO_DATA
            iny
            cpy  #8
            bne  -
        }}
    }

}

wavfile {
    ; module to parse the header data of a .wav file

    const ubyte WAVE_FORMAT_PCM        =  $1
    const ubyte WAVE_FORMAT_ADPCM      =  $2
    const ubyte WAVE_FORMAT_IEEE_FLOAT =  $3
    const ubyte WAVE_FORMAT_ALAW       =  $6
    const ubyte WAVE_FORMAT_MULAW      =  $7
    const ubyte WAVE_FORMAT_DVI_ADPCM  =  $11

    uword sample_rate
    ubyte bits_per_sample
    uword data_offset
    ubyte wavefmt
    ubyte nchannels
    uword block_align
    long data_size

    sub parse_header(uword wav_data) -> bool {
        ; "RIFF" , filesize (int32) , "WAVE", "fmt ", fmtsize (int32)
        uword @zp header = wav_data
        if header[0]!=iso:'R' or header[1]!=iso:'I' or header[2]!=iso:'F' or header[3]!=iso:'F'
            or header[8]!=iso:'W' or header[9]!=iso:'A' or header[10]!=iso:'V' or header[11]!=iso:'E'
            or header[12]!=iso:'f' or header[13]!=iso:'m' or header[14]!=iso:'t' or header[15]!=iso:' ' {
            return false
        }
        ; uword filesize = peekw(header+4)
        uword chunksize = peekw(header+16)
        wavefmt = peek(header+20)
        nchannels = peek(header+22)
        sample_rate = peekw(header+24)    ; we assume sample rate <= 65535 so we can ignore the upper word
        block_align = peekw(header+32)
        bits_per_sample = peek(header+34)
        if wavefmt==WAVE_FORMAT_DVI_ADPCM or wavefmt==WAVE_FORMAT_ADPCM
            bits_per_sample *= 4

        ; skip chunks until we reach the 'data' chunk
        header += chunksize + 20
        repeat {
            chunksize = peekw(header+4)        ; assume chunk size never exceeds 64kb so ignore upper word
            if header[0]==iso:'d' and header[1]==iso:'a' and header[2]==iso:'t' and header[3]==iso:'a'
                break
            header += 8 + chunksize
        }

        data_size = mklong2(peekw(header+6), chunksize)
        data_offset = header + 8 - wav_data
        return true
    }
}

adpcm {

    ; IMA ADPCM decoder.  Supports mono and stereo streams.
    ; https://wiki.multimedia.cx/index.php/IMA_ADPCM
    ; https://wiki.multimedia.cx/index.php/Microsoft_IMA_ADPCM

    ; IMA ADPCM encodes two 16-bit PCM audio samples in 1 byte (1 word per nibble)
    ; thus compressing the audio data by a factor of 4.
    ; The encoding precision is about 13 bits per sample so it's a lossy compression scheme.
    ;
    ; HOW TO CREATE IMA-ADPCM ENCODED AUDIO? Use sox or ffmpeg like so (example):
    ; $ sox --guard source.mp3 -r 8000 -c 1 -e ima-adpcm out.wav trim 01:27.50 00:09
    ; $ ffmpeg -i source.mp3 -ss 00:01:27.50 -to 00:01:36.50  -ar 8000 -ac 1 -c:a adpcm_ima_wav -block_size 256 -map_metadata -1 -bitexact out.wav
    ; And/or use a tool such as https://github.com/dbry/adpcm-xq  (make sure to set the correct block size, -b8)
    ;
    ; NOTE: sox may generate IMA-ADPCM files with a block size different than 256 bytes, which is not supported by this decoder. Use ffmpeg instead.
    ;
    ; NOTE: for speed reasons this implementation doesn't guard against clipping errors.
    ;       if the output sounds distorted, lower the volume of the source waveform to 80% and try again etc.


    ; IMA-ADPCM file data stream format:
    ; If the IMA data is mono, an individual chunk of data begins with the following preamble:
    ; bytes 0-1:   initial predictor (in little-endian format)
    ; byte 2:      initial index
    ; byte 3:      unknown, usually 0 and is probably reserved
    ; If the IMA data is stereo, a chunk begins with two preambles, one for the left audio channel and one for the right channel.
    ; (so we have 8 bytes of preamble).
    ; The remaining bytes in the chunk are the IMA nibbles. The first 4 bytes, or 8 nibbles,
    ; belong to the left channel and -if it's stereo- the next 4 bytes belong to the right channel.


    byte[] t_index = [ -1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
    uword[] t_step = [
            7, 8, 9, 10, 11, 12, 13, 14,
            16, 17, 19, 21, 23, 25, 28, 31,
            34, 37, 41, 45, 50, 55, 60, 66,
            73, 80, 88, 97, 107, 118, 130, 143,
            157, 173, 190, 209, 230, 253, 279, 307,
            337, 371, 408, 449, 494, 544, 598, 658,
            724, 796, 876, 963, 1060, 1166, 1282, 1411,
            1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024,
            3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
            7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
            15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
            32767]

    uword @requirezp predict       ; decoded 16 bit pcm sample for first channel.
    uword @requirezp predict_2     ; decoded 16 bit pcm sample for second channel.
    ubyte @requirezp index
    ubyte @requirezp index_2
    uword @requirezp pstep
    uword @requirezp pstep_2

    sub init(uword startPredict, ubyte startIndex) {
        ; initialize first decoding channel.
        predict = startPredict
        index = startIndex
        pstep = t_step[index]
    }

    sub init_second(uword startPredict_2, ubyte startIndex_2) {
        ; initialize second decoding channel.
        predict_2 = startPredict_2
        index_2 = startIndex_2
        pstep_2 = t_step[index_2]
    }

    sub decode_nibble(ubyte @zp nibble) {
        ; Decoder for a single nibble for the first channel. (value of 'nibble' needs to be strictly 0-15 !)
        ; This is the hotspot of the decoder algorithm!
        ; Note that the generated assembly from this is pretty efficient,
        ; rewriting it by hand in asm seems to improve it only ~10%.
        cx16.r0s = 0                ; difference
        if nibble & %0100 !=0
            cx16.r0s += pstep
        pstep >>= 1
        if nibble & %0010 !=0
            cx16.r0s += pstep
        pstep >>= 1
        if nibble & %0001 !=0
            cx16.r0s += pstep
        pstep >>= 1
        cx16.r0s += pstep
        if nibble & %1000 !=0
            predict -= cx16.r0
        else
            predict += cx16.r0

        ; NOTE: the original C/Python code uses a 32 bits prediction value and clips it to a 16 bit word
        ;       but for speed reasons we only work with 16 bit words here all the time (with possible clipping error)
        ; if predicted > 32767:
        ;    predicted = 32767
        ; elif predicted < -32767:
        ;    predicted = - 32767

        index += t_index[nibble] as ubyte
        if_neg
            index = 0
        else if index >= len(t_step)-1
            index = len(t_step)-1
        pstep = t_step[index]
    }

    sub decode_nibble_second(ubyte @zp nibble) {
        ; Decoder for a single nibble for the second channel. (value of 'nibble' needs to be strictly 0-15 !)
        ; This is the hotspot of the decoder algorithm!
        ; Note that the generated assembly from this is pretty efficient,
        ; rewriting it by hand in asm seems to improve it only ~10%.
        cx16.r0s = 0                ; difference
        if nibble & %0100 !=0
            cx16.r0s += pstep_2
        pstep_2 >>= 1
        if nibble & %0010 !=0
            cx16.r0s += pstep_2
        pstep_2 >>= 1
        if nibble & %0001 !=0
            cx16.r0s += pstep_2
        pstep_2 >>= 1
        cx16.r0s += pstep_2
        if nibble & %1000 !=0
            predict_2 -= cx16.r0
        else
            predict_2 += cx16.r0

        ; NOTE: the original C/Python code uses a 32 bits prediction value and clips it to a 16 bit word
        ;       but for speed reasons we only work with 16 bit words here all the time (with possible clipping error)
        ; if predicted > 32767:
        ;    predicted = 32767
        ; elif predicted < -32767:
        ;    predicted = - 32767

        index_2 += t_index[nibble] as ubyte
        if_neg
            index_2 = 0
        else if index_2 >= len(t_step)-1
            index_2 = len(t_step)-1
        pstep_2 = t_step[index_2]
    }
}

zsmkit2 {
    ; extsubs for ZSMKIT version 2

	const ubyte ZSMKitBank = 1
	extsub @bank ZSMKitBank $A000 = zsm_init_engine(uword lowram @XY) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A003 = zsm_tick(ubyte type @A) clobbers(A, X, Y)
	extsub $A003 = zsm_tick_isr(ubyte type @A) clobbers(A, X, Y)

	extsub @bank ZSMKitBank $A006 = zsm_play(ubyte prio @X) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A009 = zsm_stop(ubyte prio @X) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A00C = zsm_rewind(ubyte prio @X) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A00F = zsm_close(ubyte prio @X) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A012 = zsm_getloop(ubyte prio @X) -> bool @Pc, uword @XY, ubyte @A
	extsub @bank ZSMKitBank $A015 = zsm_getptr(ubyte prio @X) -> bool @Pc, uword @XY, ubyte @A
	extsub @bank ZSMKitBank $A018 = zsm_getksptr(ubyte prio @X) clobbers(A) -> uword @XY
	extsub @bank ZSMKitBank $A01B = zsm_setbank(ubyte prio @X, ubyte bank @A)
	extsub @bank ZSMKitBank $A01E = zsm_setmem(ubyte prio @X, uword data_ptr @AY) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A021 = zsm_setatten(ubyte prio @X, ubyte value @A) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A024 = zsm_setcb(ubyte prio @X, uword func_ptr @AY) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A027 = zsm_clearcb(ubyte prio @X) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A02A = zsm_getstate(ubyte prio @X) clobbers(X) -> bool @Pc, bool @Pz, uword @AY
	extsub @bank ZSMKitBank $A02D = zsm_setrate(ubyte prio @X, uword rate @AY) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A030 = zsm_getrate(ubyte prio @X) clobbers() -> uword @AY
	extsub @bank ZSMKitBank $A033 = zsm_setloop(ubyte prio @X, bool loop @Pc) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A036 = zsm_opmatten(ubyte prio @X, ubyte channel @Y, ubyte value @A) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A039 = zsm_psgatten(ubyte prio @X, ubyte channel @Y, ubyte value @A) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A03C = zsm_pcmatten(ubyte prio @X, ubyte value @A) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A03F = zsm_set_int_rate(ubyte value @A, ubyte frac @Y) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A042 = zsm_getosptr(ubyte prio @X) clobbers(A) -> uword @XY
	extsub @bank ZSMKitBank $A045 = zsm_getpsptr(ubyte prio @X) clobbers(A) -> uword @XY
	extsub @bank ZSMKitBank $A048 = zcm_setbank(ubyte slot @X, ubyte bank @A)
	extsub @bank ZSMKitBank $A04B = zcm_setmem(ubyte slot @X, uword data_ptr @AY) clobbers(A)
	extsub @bank ZSMKitBank $A04E = zcm_play(ubyte slot @X, ubyte volume @A) clobbers(A, X)
	extsub @bank ZSMKitBank $A051 = zcm_stop() clobbers(A)

	extsub @bank ZSMKitBank $A054 = zsmkit_setisr() clobbers(A)
	extsub @bank ZSMKitBank $A057 = zsmkit_clearisr() clobbers(A)
	extsub @bank ZSMKitBank $A05A = zsmkit_version() -> ubyte @A, ubyte @X

	extsub @bank ZSMKitBank $A05D = zsm_set_ondeck_bank(ubyte prio @X, ubyte bank @A)
	extsub @bank ZSMKitBank $A060 = zsm_set_ondeck_mem(ubyte prio @X, uword data_ptr @AY) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A063 = zsm_clear_ondeck(ubyte prio @X) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A066 = zsm_midi_init(ubyte iobase @A, bool parallel @X, bool callback @Pc) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A069 = zsm_psg_suspend(ubyte channel @Y, bool suspend @Pc) clobbers(A, X, Y)
	extsub @bank ZSMKitBank $A06C = zsm_opm_suspend(ubyte channel @Y, bool suspend @Pc) clobbers(A, X, Y)


	sub load_zsmkit() -> bool {
        cx16.rambank(ZSMKitBank)
        return diskio.load_raw(iso:"/SHELL-FILES/commands/ZSMKIT-A000.BIN",$A000)!=0
	}

	sub play_music() {
		uword zsmptr
		ubyte zsmbank

		zsm_setbank(0, ZSMKitBank+1)
		zsm_setmem(0, $A000)

		zsm_play(0)
		repeat {
			sys.waitvsync()
			void, zsmptr, zsmbank = zsm_getptr(0)
			shell.print_ubhex(zsmbank, false)
			shell.print(":")
			shell.print_uwhex(zsmptr, false)
			shell.print("\x9d\x9d\x9d\x9d\x9d\x9d\x9d")       ; cursor lefts
			void cbm.STOP()
			if_z {
			    shell.print("\nbreak\n")
			    break
			}
		}

		zsm_stop(0)
	}

	sub play_digi() {
		zcm_setbank(1, ZSMKitBank+1)
		zcm_setmem(1, $A000)
		zcm_play(1, 12)
		repeat {
		    ; there is no indication of end of playback, so user has to STOP it manually
			sys.waitvsync()
			void cbm.STOP()
			if_z {
			    shell.print("\nbreak\n")
			    break
			}
		}
		zcm_stop()
	}

    ubyte[255] zsmkit_lowram

    struct ZCMHeader {
        uword address
        ubyte bank
        uword size_lo
        ubyte size_hi
        ubyte vera_cfg
        ubyte vera_rate
    }
}