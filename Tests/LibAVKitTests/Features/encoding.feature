Feature: Audio Encoding
  LibAVKit encodes audio files from one format to another,
  preserving audio properties and applying codec-specific settings.

  # --- CD source (44.1kHz / 16-bit stereo) to all target formats ---

  Scenario Outline: Encode CD-quality source to target format
    Given a "<source_codec>" file at "<source_fixture>"
    When I encode it to "<target_format>" with settings "<encoding_settings>"
    Then the output file exists
    And the sample rate is <expected_sample_rate>
    And the channel count is 2

    Examples: Lossless targets
      | source_codec | source_fixture                 | target_format | encoding_settings | expected_sample_rate |
      | WAV          | wav/cd-16bit-stereo.wav        | flac          | flac_default      | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | alac          | lossless          | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | wav           | lossless          | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | aiff          | lossless          | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | wavpack       | lossless          | 44100                |

    Examples: MP3 variants
      | source_codec | source_fixture                 | target_format | encoding_settings | expected_sample_rate |
      | FLAC         | flac/cd-16bit-stereo.flac      | mp3           | mp3_cbr_128       | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | mp3           | mp3_vbr_v2        | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | mp3           | mp3_abr_192       | 44100                |

    Examples: AAC variants
      | source_codec | source_fixture                 | target_format | encoding_settings | expected_sample_rate |
      | FLAC         | flac/cd-16bit-stereo.flac      | aac           | aac_lc_128        | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | aac           | aac_hev1_64       | 44100                |
      | FLAC         | flac/cd-16bit-stereo.flac      | aac           | aac_hev2_48       | 44100                |

    Examples: Vorbis
      | source_codec | source_fixture                 | target_format | encoding_settings | expected_sample_rate |
      | FLAC         | flac/cd-16bit-stereo.flac      | vorbis        | vorbis_q5         | 44100                |

  Scenario: Encode CD-quality FLAC to Opus requires 48kHz resample
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I encode it to "opus" with settings "opus_128" at sample rate 48000
    Then the output file exists
    And the sample rate is 48000
    And the channel count is 2

  # --- Hi-res source to lossless formats ---

  Scenario Outline: Encode hi-res source to lossless format
    Given a "<source_codec>" file at "<source_fixture>"
    When I encode it to "<target_format>" with settings "<encoding_settings>"
    Then the output file exists
    And the sample rate is <expected_sample_rate>
    And the channel count is 2

    Examples: 96kHz / 24-bit
      | source_codec | source_fixture                    | target_format | encoding_settings | expected_sample_rate |
      | WAV          | wav/hires96-24bit-stereo.wav      | flac          | flac_default      | 96000                |
      | FLAC         | flac/hires96-24bit-stereo.flac    | alac          | lossless          | 96000                |
      | FLAC         | flac/hires96-24bit-stereo.flac    | wav           | lossless          | 96000                |
      | FLAC         | flac/hires96-24bit-stereo.flac    | aiff          | lossless          | 96000                |
      | FLAC         | flac/hires96-24bit-stereo.flac    | wavpack       | lossless          | 96000                |

    Examples: 192kHz / 24-bit
      | source_codec | source_fixture                    | target_format | encoding_settings | expected_sample_rate |
      | WAV          | wav/hires192-24bit-stereo.wav     | flac          | flac_default      | 192000               |
      | FLAC         | flac/hires192-24bit-stereo.flac   | wav           | lossless          | 192000               |
      | FLAC         | flac/hires192-24bit-stereo.flac   | alac          | lossless          | 192000               |

  # --- Downsampling scenarios ---

  Scenario Outline: Downsample hi-res source during encoding
    Given a "<source_codec>" file at "<source_fixture>"
    When I encode it to "<target_format>" with settings "<encoding_settings>" at sample rate <config_sample_rate>
    Then the output file exists
    And the sample rate is <expected_sample_rate>
    And the channel count is 2

    Examples:
      | source_codec | source_fixture                    | target_format | encoding_settings | config_sample_rate | expected_sample_rate |
      | FLAC         | flac/hires192-24bit-stereo.flac   | flac          | flac_default      | 44100              | 44100                |
      | FLAC         | flac/hires96-24bit-stereo.flac    | mp3           | mp3_cbr_128       | 44100              | 44100                |

  Scenario: Reduce bit depth during encoding
    Given a "FLAC" file at "flac/hires96-24bit-stereo.flac"
    When I encode it to "flac" with settings "flac_default" at bit depth 16
    Then the output file exists
    And the sample rate is 96000
    And the bit depth is 16

  Scenario: Reduce both sample rate and bit depth
    Given a "FLAC" file at "flac/hires192-24bit-stereo.flac"
    When I encode it to "flac" with settings "flac_default" at sample rate 44100 and bit depth 16
    Then the output file exists
    And the sample rate is 44100
    And the bit depth is 16
