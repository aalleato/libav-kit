#ifndef CFFMPEG_SHIM_H
#define CFFMPEG_SHIM_H

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libavutil/audio_fifo.h>
#include <libswresample/swresample.h>

// MARK: - Dolby Atmos Detection Helpers

/// Check if codec is E-AC-3 (Dolby Digital Plus)
static inline int harmonica_is_eac3(enum AVCodecID codec_id) {
    return codec_id == AV_CODEC_ID_EAC3;
}

/// Check if codec is TrueHD
static inline int harmonica_is_truehd(enum AVCodecID codec_id) {
    return codec_id == AV_CODEC_ID_TRUEHD;
}

/// Get the E-AC-3 Atmos profile value (FF_PROFILE_EAC3_DDP_ATMOS = 30)
static inline int harmonica_get_eac3_atmos_profile(void) {
    return 30; // FF_PROFILE_EAC3_DDP_ATMOS
}

/// Get E-AC-3 codec ID for comparison
static inline enum AVCodecID harmonica_get_eac3_codec_id(void) {
    return AV_CODEC_ID_EAC3;
}

/// Get TrueHD codec ID for comparison
static inline enum AVCodecID harmonica_get_truehd_codec_id(void) {
    return AV_CODEC_ID_TRUEHD;
}

#endif /* CFFMPEG_SHIM_H */
