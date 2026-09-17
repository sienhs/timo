package com.ssafy.timo.global.storage;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.io.IOException;
import java.io.UncheckedIOException;

/**
 * 실제 S3 버킷에 저장된 이미지를 다루는 {@link ImageStorage} 구현체. {@code local} 과 {@code test} 를
 * 제외한 프로파일에서 뜬다 - {@link PlaceholderImageStorage} 와 프로파일 조건이 서로 여집합이어야 한다는
 * 점은 {@link com.ssafy.timo.domain.auth.service.SolapiSmsSender} 와 같은 사정이다.
 *
 * <p>버킷({@code infra/modules/image-storage/public.tf})은 퍼블릭 접근이 막혀 있어, 읽기는
 * CloudFront({@code baseUrl})를 거쳐야만 가능하다. 자격증명은 여기서 직접 읽지 않고 AWS SDK
 * 기본 자격증명 체인(환경변수 {@code AWS_ACCESS_KEY_ID}/{@code AWS_SECRET_ACCESS_KEY})에 맡긴다 -
 * {@code infra/modules/image-storage/outputs.tf} 의 {@code runtime_environment} 가 이 값들을
 * 배포 환경에 주입한다.
 *
 * <p>쓰기(업로드)도 같은 자격증명으로 이 서버가 직접 한다 - presigned URL 로 클라이언트가 직접 올리는
 * 방식은 쓰지 않는다. key 에 소속 엔티티(공연 등) id 가 들어가는데, 그 id 는 엔티티 저장 이후에나
 * 정해지기 때문이다.
 */
@Slf4j
@Component
@Profile("!local & !test")
public class S3ImageStorage implements ImageStorage {

    private final S3Client s3Client;
    private final String bucketName;
    private final String baseUrl;

    /**
     * 생성자가 둘이라 {@code @Autowired} 로 스프링이 쓸 쪽을 명시한다 - 없으면 스프링이 둘 중
     * 뭘 골라야 할지 판단하지 못해 빈 생성에 실패한다({@code S3Client} 는 빈으로 등록돼 있지 않다).
     */
    @Autowired
    public S3ImageStorage(@Value("${app.image.bucket-name}") String bucketName,
                           @Value("${app.image.base-url}") String baseUrl,
                           @Value("${app.image.region}") String region) {
        this(bucketName, baseUrl, S3Client.builder().region(Region.of(region)).build());
    }

    /** {@code S3Client} 를 목으로 바꿔 넣기 위한 테스트용 생성자. */
    S3ImageStorage(String bucketName, String baseUrl, S3Client s3Client) {
        this.bucketName = bucketName;
        this.baseUrl = baseUrl;
        this.s3Client = s3Client;
    }

    @Override
    public String getUrl(String imageKey) {
        if (imageKey == null) {
            return null;
        }
        return baseUrl + "/" + imageKey;
    }

    /** 삭제 실패는 경고 로그만 남긴다 - {@link ImageStorage#delete} 계약대로 예외를 던지지 않는다. */
    @Override
    public void delete(String imageKey) {
        if (imageKey == null) {
            return;
        }
        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(bucketName)
                    .key(imageKey)
                    .build());
        } catch (S3Exception e) {
            log.warn("S3 이미지 삭제 실패: imageKey={}", imageKey, e);
        }
    }

    /**
     * 업로드 실패(content type 미지원)는 {@link ImageKeys#generate} 가 던지는 예외를 그대로 전파한다.
     * S3 쪽 실패(자격증명·권한 등)도 그대로 전파해 호출 쪽 트랜잭션이 롤백되게 한다 - 일부만 업로드된
     * 채로 공연이 저장되는 것보다는, 이미 올라간 객체가 고아로 남는 쪽이 낫다.
     */
    @Override
    public String upload(String keyPrefix, MultipartFile file) {
        String key = ImageKeys.generate(keyPrefix, file.getContentType());

        try {
            s3Client.putObject(PutObjectRequest.builder()
                            .bucket(bucketName)
                            .key(key)
                            .contentType(file.getContentType())
                            .build(),
                    RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
        } catch (IOException e) {
            throw new UncheckedIOException("S3 이미지 업로드 실패: key=" + key, e);
        }

        return key;
    }
}
