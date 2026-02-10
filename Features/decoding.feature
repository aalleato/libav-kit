Feature: Audio Decoding
  LibAVKit decodes audio files from all supported source codecs.
  Each source is decoded and re-encoded to FLAC to verify the decoder
  correctly reads the audio stream and preserves properties.

  Scenario Outline: Decode source codec to FLAC
    Given a "<source_codec>" file at "<source_fixture>"
    When I encode it to "flac" with settings "flac_default"
    Then the output file exists
    And the sample rate is <expected_sample_rate>
    And the channel count is <expected_channels>

    Examples: FLAC sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | FLAC         | flac/cd-16bit-stereo.flac         | 44100                | 2                 |
      | FLAC         | flac/cd-16bit-mono.flac           | 44100                | 1                 |
      | FLAC         | flac/hires88-24bit-stereo.flac    | 88200                | 2                 |
      | FLAC         | flac/hires88-24bit-mono.flac      | 88200                | 1                 |
      | FLAC         | flac/hires96-24bit-stereo.flac    | 96000                | 2                 |
      | FLAC         | flac/hires96-24bit-mono.flac      | 96000                | 1                 |
      | FLAC         | flac/hires192-24bit-stereo.flac   | 192000               | 2                 |
      | FLAC         | flac/hires192-24bit-mono.flac     | 192000               | 1                 |

    Examples: WAV sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | WAV          | wav/cd-16bit-stereo.wav           | 44100                | 2                 |
      | WAV          | wav/cd-16bit-mono.wav             | 44100                | 1                 |
      | WAV          | wav/hires88-24bit-stereo.wav      | 88200                | 2                 |
      | WAV          | wav/hires88-24bit-mono.wav        | 88200                | 1                 |
      | WAV          | wav/hires96-24bit-stereo.wav      | 96000                | 2                 |
      | WAV          | wav/hires96-24bit-mono.wav        | 96000                | 1                 |
      | WAV          | wav/hires192-24bit-stereo.wav     | 192000               | 2                 |
      | WAV          | wav/hires192-24bit-mono.wav       | 192000               | 1                 |

    Examples: ALAC sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | ALAC         | alac/cd-16bit-stereo.m4a          | 44100                | 2                 |
      | ALAC         | alac/cd-16bit-mono.m4a            | 44100                | 1                 |
      | ALAC         | alac/hires88-24bit-stereo.m4a     | 88200                | 2                 |
      | ALAC         | alac/hires88-24bit-mono.m4a       | 88200                | 1                 |
      | ALAC         | alac/hires96-24bit-stereo.m4a     | 96000                | 2                 |
      | ALAC         | alac/hires96-24bit-mono.m4a       | 96000                | 1                 |
      | ALAC         | alac/hires192-24bit-stereo.m4a    | 192000               | 2                 |
      | ALAC         | alac/hires192-24bit-mono.m4a      | 192000               | 1                 |

    Examples: AIFF sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | AIFF         | aiff/cd-16bit-stereo.aiff         | 44100                | 2                 |
      | AIFF         | aiff/cd-16bit-mono.aiff           | 44100                | 1                 |

    Examples: WavPack sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | WavPack      | wv/cd-16bit-stereo.wv             | 44100                | 2                 |
      | WavPack      | wv/cd-16bit-mono.wv               | 44100                | 1                 |

    Examples: Lossy sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | MP3          | mp3/cd-stereo.mp3                 | 44100                | 2                 |
      | MP3          | mp3/cd-mono.mp3                   | 44100                | 1                 |
      | AAC          | aac/cd-stereo.m4a                 | 44100                | 2                 |
      | AAC          | aac/cd-mono.m4a                   | 44100                | 1                 |
      | Vorbis       | vorbis/cd-stereo.ogg              | 44100                | 2                 |
      | Vorbis       | vorbis/cd-mono.ogg                | 44100                | 1                 |
      | Opus         | opus/cd-stereo.opus               | 48000                | 2                 |
      | Opus         | opus/cd-mono.opus                 | 48000                | 1                 |
