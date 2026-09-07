package com.ssafy.timo.domain.artist.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 아티스트를 참조한 경우. */
public class ArtistNotFoundException extends BusinessException {

    public ArtistNotFoundException(Long artistId) {
        super(ArtistErrorCode.ARTIST_NOT_FOUND,
                ArtistErrorCode.ARTIST_NOT_FOUND.getMessage() + " (artistId=" + artistId + ")");
    }
}
