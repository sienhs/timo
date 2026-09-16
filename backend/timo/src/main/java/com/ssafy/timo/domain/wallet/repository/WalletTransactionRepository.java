package com.ssafy.timo.domain.wallet.repository;

import com.ssafy.timo.domain.wallet.entity.WalletTransaction;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface WalletTransactionRepository extends JpaRepository<WalletTransaction, Long> {

    // 같은 순간에 생긴 거래끼리는 createdAt 이 같을 수 있어 id 를 2차 정렬 기준으로 둔다.
    List<WalletTransaction> findAllByMemberIdOrderByCreatedAtDescIdDesc(Long memberId, Pageable pageable);
}
