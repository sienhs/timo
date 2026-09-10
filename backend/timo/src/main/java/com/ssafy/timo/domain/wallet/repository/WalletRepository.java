package com.ssafy.timo.domain.wallet.repository;

import com.ssafy.timo.domain.wallet.entity.Wallet;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface WalletRepository extends JpaRepository<Wallet, Long> {
}
