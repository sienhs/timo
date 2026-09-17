package com.ssafy.timo.global.firebase;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;

/** Firebase Admin SDK는 ADC를 사용한다.
 *
 * <p>운영에서는 워크로드의 서비스 계정, EC2 같은 외부 환경에서는
 * {@code GOOGLE_APPLICATION_CREDENTIALS}가 가리키는 Secret 파일을 쓴다. 키 경로를
 * 설정 파일이나 소스에 넣지 않아 배포 방식이 바뀌어도 코드가 바뀌지 않는다.
 */
@Configuration
@ConditionalOnProperty(prefix = "app.firebase", name = "messaging-enabled", havingValue = "true")
public class FirebaseConfig {

    @Bean
    FirebaseApp firebaseApp() throws IOException {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.getApplicationDefault())
                .build();
        return FirebaseApp.initializeApp(options);
    }
}
