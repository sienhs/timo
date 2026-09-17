package com.ssafy.timo.global.init;

import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * 클래스패스 정적 리소스를 {@link MultipartFile} 로 감싼다.
 *
 * <p>{@link com.ssafy.timo.global.storage.ImageStorage#upload} 는 HTTP 업로드를 전제로
 * {@link MultipartFile} 을 받는데, {@link LocalDataSeeder}의 데모 이미지는 HTTP 요청이 아니라
 * 클래스패스 파일이 출처라 스프링이 주는 구현체를 쓸 수 없어 이 어댑터가 필요하다.
 */
class ClasspathMultipartFile implements MultipartFile {

    private final String name;
    private final String contentType;
    private final byte[] content;

    ClasspathMultipartFile(String name, String contentType, byte[] content) {
        this.name = name;
        this.contentType = contentType;
        this.content = content;
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public String getOriginalFilename() {
        return name;
    }

    @Override
    public String getContentType() {
        return contentType;
    }

    @Override
    public boolean isEmpty() {
        return content.length == 0;
    }

    @Override
    public long getSize() {
        return content.length;
    }

    @Override
    public byte[] getBytes() {
        return content;
    }

    @Override
    public InputStream getInputStream() {
        return new ByteArrayInputStream(content);
    }

    @Override
    public void transferTo(File dest) throws IOException {
        try (FileOutputStream out = new FileOutputStream(dest)) {
            out.write(content);
        }
    }
}
