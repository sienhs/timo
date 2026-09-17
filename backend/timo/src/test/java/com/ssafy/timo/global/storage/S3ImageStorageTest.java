package com.ssafy.timo.global.storage;

import com.ssafy.timo.global.storage.exception.UnsupportedImageTypeException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.io.IOException;
import java.io.UncheckedIOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;

@ExtendWith(MockitoExtension.class)
class S3ImageStorageTest {

    private static final String BUCKET = "timo-images";
    private static final String BASE_URL = "https://cdn.ticketmoa.site";

    @Mock
    private S3Client s3Client;

    @Captor
    private ArgumentCaptor<PutObjectRequest> putObjectRequestCaptor;

    @Nested
    @DisplayName("getUrl")
    class GetUrl {

        @Test
        @DisplayName("key가 null이면 null을 돌려준다")
        void returnsNullForNullKey() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);

            assertThat(storage.getUrl(null)).isNull();
        }

        @Test
        @DisplayName("baseUrl 뒤에 key를 그대로 붙인다")
        void appendsKeyToBaseUrl() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);

            assertThat(storage.getUrl("concert/1/poster.jpg"))
                    .isEqualTo("https://cdn.ticketmoa.site/concert/1/poster.jpg");
        }
    }

    @Nested
    @DisplayName("delete")
    class Delete {

        @Test
        @DisplayName("key가 null이면 S3를 호출하지 않는다")
        void doesNothingForNullKey() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);

            storage.delete(null);

            then(s3Client).should(never()).deleteObject(any(DeleteObjectRequest.class));
        }

        @Test
        @DisplayName("bucket과 key로 deleteObject를 호출한다")
        void deletesByBucketAndKey() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);

            storage.delete("concert/1/poster.jpg");

            then(s3Client).should().deleteObject(DeleteObjectRequest.builder()
                    .bucket(BUCKET)
                    .key("concert/1/poster.jpg")
                    .build());
        }

        @Test
        @DisplayName("S3 호출이 실패해도 예외를 던지지 않는다")
        void swallowsS3Exception() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);
            given(s3Client.deleteObject(any(DeleteObjectRequest.class)))
                    .willThrow(S3Exception.builder().message("boom").build());

            assertThatCode(() -> storage.delete("concert/1/poster.jpg")).doesNotThrowAnyException();
        }
    }

    @Nested
    @DisplayName("upload")
    class Upload {

        @Test
        @DisplayName("지원하는 content type이면 keyPrefix로 시작하는 key로 putObject를 호출하고 그 key를 돌려준다")
        void uploadsAndReturnsGeneratedKey() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);
            MultipartFile file = new MockMultipartFile("poster", "poster.png", "image/png", "poster-bytes".getBytes());
            given(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                    .willReturn(PutObjectResponse.builder().build());

            String key = storage.upload("concert/1/poster", file);

            assertThat(key).startsWith("concert/1/poster/").endsWith(".png");
            then(s3Client).should().putObject(putObjectRequestCaptor.capture(), any(RequestBody.class));
            PutObjectRequest request = putObjectRequestCaptor.getValue();
            assertThat(request.bucket()).isEqualTo(BUCKET);
            assertThat(request.key()).isEqualTo(key);
            assertThat(request.contentType()).isEqualTo("image/png");
        }

        @Test
        @DisplayName("지원하지 않는 content type이면 S3를 호출하지 않고 예외를 던진다")
        void rejectsUnsupportedContentType() {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);
            MultipartFile file = new MockMultipartFile("poster", "poster.txt", "text/plain", "not-an-image".getBytes());

            assertThatThrownBy(() -> storage.upload("concert/1/poster", file))
                    .isInstanceOf(UnsupportedImageTypeException.class);
            then(s3Client).should(never()).putObject(any(PutObjectRequest.class), any(RequestBody.class));
        }

        @Test
        @DisplayName("파일을 읽지 못하면 UncheckedIOException으로 감싸 던진다")
        void wrapsIOExceptionFromFile() throws IOException {
            S3ImageStorage storage = new S3ImageStorage(BUCKET, BASE_URL, s3Client);
            MultipartFile file = mock(MultipartFile.class);
            given(file.getContentType()).willReturn("image/png");
            given(file.getInputStream()).willThrow(new IOException("disk error"));

            assertThatThrownBy(() -> storage.upload("concert/1/poster", file))
                    .isInstanceOf(UncheckedIOException.class);
            then(s3Client).should(never()).putObject(any(PutObjectRequest.class), any(RequestBody.class));
        }
    }
}
