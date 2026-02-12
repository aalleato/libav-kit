Feature: Audio Playback
  LibAVKit plays audio files from all supported codecs.
  Playback decodes audio and sends it to the system audio output.
  The player reports state transitions, duration, and current position.

  # --- Basic playback across formats ---

  Scenario Outline: Play audio file to completion
    Given a "<source_codec>" file at "<source_fixture>"
    When I play the file
    Then the playback state is "completed"
    And the reported duration matches the file duration
    And the reported sample rate is <expected_sample_rate>
    And the reported channel count is <expected_channels>

    Examples: Lossless sources
      | source_codec | source_fixture                 | expected_sample_rate | expected_channels |
      | FLAC         | flac/cd-16bit-stereo.flac      | 44100                | 2                 |
      | FLAC         | flac/cd-16bit-mono.flac        | 44100                | 1                 |
      | WAV          | wav/cd-16bit-stereo.wav        | 44100                | 2                 |
      | ALAC         | alac/cd-16bit-stereo.m4a       | 44100                | 2                 |
      | AIFF         | aiff/cd-16bit-stereo.aiff      | 44100                | 2                 |
      | WavPack      | wv/cd-16bit-stereo.wv          | 44100                | 2                 |

    Examples: Lossy sources
      | source_codec | source_fixture                 | expected_sample_rate | expected_channels |
      | MP3          | mp3/cd-stereo.mp3              | 44100                | 2                 |
      | MP3          | mp3/cd-mono.mp3                | 44100                | 1                 |
      | AAC          | aac/cd-stereo.m4a              | 44100                | 2                 |
      | Vorbis       | vorbis/cd-stereo.ogg           | 44100                | 2                 |
      | Opus         | opus/cd-stereo.opus            | 48000                | 2                 |

    Examples: Hi-res sources
      | source_codec | source_fixture                    | expected_sample_rate | expected_channels |
      | FLAC         | flac/hires96-24bit-stereo.flac    | 96000                | 2                 |
      | FLAC         | flac/hires192-24bit-stereo.flac   | 192000               | 2                 |
      | WAV          | wav/hires96-24bit-stereo.wav      | 96000                | 2                 |

  # --- Pause and resume ---

  Scenario: Pause and resume playback
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I start playing the file
    And I pause playback
    Then the playback state is "paused"
    When I resume playback
    Then the playback state is "playing"

  # --- Stop ---

  Scenario: Stop playback
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I start playing the file
    And I stop playback
    Then the playback state is "stopped"
    And the playback position is 0

  # --- Seeking ---

  Scenario Outline: Seek to position during playback
    Given a "<source_codec>" file at "<source_fixture>"
    When I start playing the file
    And I seek to <seek_seconds> seconds
    Then the playback position is approximately <seek_seconds> seconds
    And the playback state is "playing"

    Examples:
      | source_codec | source_fixture                 | seek_seconds |
      | FLAC         | flac/cd-16bit-stereo.flac      | 0.5          |
      | MP3          | mp3/cd-stereo.mp3              | 0.5          |
      | AAC          | aac/cd-stereo.m4a              | 0.5          |
      | Opus         | opus/cd-stereo.opus            | 0.5          |

  Scenario: Seek while paused
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I start playing the file
    And I pause playback
    And I seek to 0.5 seconds
    Then the playback position is approximately 0.5 seconds
    And the playback state is "paused"

  # --- Volume ---

  Scenario: Adjust volume during playback
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I start playing the file
    And I set the volume to 0.5
    Then the volume is 0.5

  Scenario: Mute and unmute
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I start playing the file
    And I set the volume to 0.0
    Then the volume is 0.0
    When I set the volume to 1.0
    Then the volume is 1.0

  # --- Error handling ---

  Scenario: Play non-existent file throws error
    Given a non-existent file at "/nonexistent/path/to/file.flac"
    When I attempt to play the file
    Then the playback fails with an error

  Scenario: Seek beyond duration clamps to end
    Given a "FLAC" file at "flac/cd-16bit-stereo.flac"
    When I start playing the file
    And I seek to 9999 seconds
    Then the playback state is "completed"
