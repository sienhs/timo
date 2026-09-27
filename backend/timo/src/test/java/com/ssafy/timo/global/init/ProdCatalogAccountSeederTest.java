package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.goods.entity.GoodsUpload;
import com.ssafy.timo.domain.goods.entity.GoodsUploadStatus;
import com.ssafy.timo.domain.goods.repository.GoodsUploadRepository;
import com.ssafy.timo.support.IntegrationTest;

import jakarta.persistence.EntityManager;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 운영 시더의 굿즈 업로드 대장 시드. {@code ProdCatalogSeeder} 는 실제 체인 서명이 있어야 끝까지 돌아
 * 여기서는 대장을 적는 메서드만 부른다. flush 뒤 영속성 컨텍스트를 비우고 다시 읽어 실제 MySQL 행을 본다.
 */
@IntegrationTest
class ProdCatalogAccountSeederTest {

    @Autowired
    private ProdCatalogAccountSeeder accountSeeder;

    @Autowired
    private GoodsUploadRepository goodsUploadRepository;

    @Autowired
    private EntityManager entityManager;

    @Test
    @DisplayName("S3 goods/ 에 올린 파일 22건을 관리자 티켓의 UPLOADED 행으로 적는다")
    void seedGoodsUploads() {
        Long adminId = 9_001L;
        Long ticketId = 9_002L;

        accountSeeder.seedGoodsUploads(adminId, ticketId);
        entityManager.flush();
        entityManager.clear();

        List<GoodsUpload> rows = goodsUploadRepository.findAll().stream()
                .filter(upload -> upload.getTicketId().equals(ticketId))
                .toList();

        assertThat(rows).hasSize(22);
        assertThat(rows).allSatisfy(upload -> {
            assertThat(upload.getMemberId()).isEqualTo(adminId);
            assertThat(upload.getStatus()).isEqualTo(GoodsUploadStatus.UPLOADED);
            assertThat(upload.getImageKey()).startsWith("goods/");
            assertThat(upload.getCreatedAt()).isNotNull();
            assertThat(upload.getUpdatedAt()).isNotNull();
            assertThat(upload.getDeletedAt()).isNull();
        });
        assertThat(rows).extracting(GoodsUpload::getImageKey)
                .contains("goods/artist_iu.jpg", "goods/concert_movie.mp4", "goods/concert_stadium_fireworks.png");
    }
}
