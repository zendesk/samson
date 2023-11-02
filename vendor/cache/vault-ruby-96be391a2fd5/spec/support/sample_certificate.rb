module RSpec
  class SampleCertificate

    def self.cert
      <<-EOH.gsub(/^\s*/,'')
        -----BEGIN CERTIFICATE-----
        MIIETjCCAzagAwIBAgIJALOl5x95gXuxMA0GCSqGSIb3DQEBBQUAMHcxCzAJBgNV
        BAYTAkRFMQwwCgYDVQQIEwNOUlcxETAPBgNVBAcUCE3DvG5zdGVyMRMwEQYDVQQK
        EwprYWVsdW1hbmlhMRMwEQYDVQQLEwprYWVsdW1hbmlhMR0wGwYDVQQDFBRrYWxl
        dW1hbmlhQGdtYWlsLmNvbTAeFw0xNjAzMTgwOTI5NThaFw0xNjA0MTcwOTI5NTha
        MHcxCzAJBgNVBAYTAkRFMQwwCgYDVQQIEwNOUlcxETAPBgNVBAcUCE3DvG5zdGVy
        MRMwEQYDVQQKEwprYWVsdW1hbmlhMRMwEQYDVQQLEwprYWVsdW1hbmlhMR0wGwYD
        VQQDFBRrYWxldW1hbmlhQGdtYWlsLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEP
        ADCCAQoCggEBAKmPsgiAKCsOwoSGwkHWZHsp4D4ldA/5gjXIssdnH7wMfCusb69C
        NZafLxAzYqVuSoHT34s8p+cdi4zPeGJaZLqjZ9lrVT77jLhnU81lJIYmaR0puyag
        9s1QG5UwNulryOvqrXeBM3BPn+3+46jchuIZVRdqIv13a6ho8PyatrbWCxiOAOtP
        TmZOlhxWK4K/eQc5Fq/M0zgbDnVYlyWDNcqhDsB55ZrMW4n80/Bo6nCVkR+xTktw
        1eQdH+xWsHTpRVL/ooKImx0pGVy3JtIXn7ic6DCvD9OcndUumgL1DqAA35EJxRSi
        mveKz/d1YdkBEKM5UbJ6afv5/vONWKiKUKkCAwEAAaOB3DCB2TAdBgNVHQ4EFgQU
        dgcSZJbWM1LiYCInPBB2j1JKrwkwgakGA1UdIwSBoTCBnoAUdgcSZJbWM1LiYCIn
        PBB2j1JKrwmhe6R5MHcxCzAJBgNVBAYTAkRFMQwwCgYDVQQIEwNOUlcxETAPBgNV
        BAcUCE3DvG5zdGVyMRMwEQYDVQQKEwprYWVsdW1hbmlhMRMwEQYDVQQLEwprYWVs
        dW1hbmlhMR0wGwYDVQQDFBRrYWxldW1hbmlhQGdtYWlsLmNvbYIJALOl5x95gXux
        MAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAE+NAippU66HkqbIz/vy
        e47CJeTwFlfewisWhuWxnxMgKjYVg7u6TzabofraTkbcbShfxKiiI6SFY75NVGTv
        dpzR1W7HNjqoZ4coXC/oe9FGOQsrDDrwjOHuZybMOERxXQJtWnE4IgWJBzZEeyhZ
        XnQA6RAnkLIES9RXLnRnb84oYJk7xggIBF6rp08ykuBItjkOsYoouWcPd1w/7sHs
        yi4B7AOJdlSQ2iHwF0Ulvh84Sp+Q0X6wWbURvkrCYHE/y9YTS0Umt6umHfNzyljx
        euEvWAzkbmKvPr92F8hjOaLqUJyPSGnB0b/vsejt/WKWbW0IKI9xcWLC1lfc6MJo
        wrM=
        -----END CERTIFICATE-----
      EOH
    end

    def self.key
      <<-EOH.gsub(/^\s*/,'')
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEAqY+yCIAoKw7ChIbCQdZkeyngPiV0D/mCNciyx2cfvAx8K6xv
        r0I1lp8vEDNipW5KgdPfizyn5x2LjM94YlpkuqNn2WtVPvuMuGdTzWUkhiZpHSm7
        JqD2zVAblTA26WvI6+qtd4EzcE+f7f7jqNyG4hlVF2oi/XdrqGjw/Jq2ttYLGI4A
        609OZk6WHFYrgr95BzkWr8zTOBsOdViXJYM1yqEOwHnlmsxbifzT8GjqcJWRH7FO
        S3DV5B0f7FawdOlFUv+igoibHSkZXLcm0hefuJzoMK8P05yd1S6aAvUOoADfkQnF
        FKKa94rP93Vh2QEQozlRsnpp+/n+841YqIpQqQIDAQABAoIBAQCZNGPJOHqSxQhO
        lDBLKnqpqiGaJV8j2+6hyBB5CR1sXN+I2oojEbC3wmbUvYkhLnEVsylldk3DDjf7
        562/OCuRU3nOwiNJACKar4nRqNSCfYw2NHGMKp40zm/Nsb271I67UtSfiNbAYMGB
        We+7sF4TRo5S1Kx+1nsotIEhzGzQ70Z9HDPZoye6lNZDPn9jmmitdGPDfeOknBTn
        cZg6+czU3jQZ5Xk1NUrBirEhMC5xhykMK3KPj/Yj7MbQrtcRpFh/sRl0mVQ7BYo0
        eba+3zMChoQ7IYb9AzJQZDr4u+uhiHMSzzJVxmvbPKsck42jRBvYJmk+NDDpSyUH
        qPVbyR2BAoGBANYhZMLpLt+WmIn7pRNcACsSvfEsFpiZiQOdxv+/Cu7JreeG1BnW
        qxtoqGcj7nHupCj8rx5bB/kQUufDLHpDaINVhI/iFjgp5WQX4lIx32sTv7jAiqUf
        EssmSRxbTqtdsZVkeAXINmnk+S08ZDcxvvA/mDegkwai+jkiaNb5USB5AoGBAMq3
        VHhpWACG5ZhMpab/wcfPZEsCqAN8yR9U91TUJ4L6GyJzsFcBeFMnMuQhB+BiELIh
        t9QyIQvhvuOqZpHB3MgK4m6Pv0NOmRdDcIxJfLdjZj7lJsf2rbwQ2qjaTSZ/l1Vv
        W5OakOf4+AIau6BT/neuxS6Kxm+Y+49839CRNIWxAoGAXSNlSopWwxYj/1Cfus33
        nMSoLbC5m2KdAB+uoSsdvEOpCt3Qf/SptGBPb51nZ9MfQFy4ZwG9dA4voXN5cyzC
        1u1pnZP/iipfBqyE2q+quE58xAWryKq9Z/OdNWJZ05wLVCnBMvKlCGZ6I7zy8jcH
        EET5FqkXinl1UUiwRWFocjECgYEAr6apX+jP4y0ANrZ7dzf33j3bRo/Xq6Xt0+NY
        qL1oOzqiVnjuHIXekBbQJxJj886lbuR+mDSTo+sI79bQJ45W01NzHqAZ96VcS+cY
        18Y5deKATxFaSDx8EBB+l38JCMnYBKSIMl7lHswBgjlNyL/fKC9dFlYTWdGycIOg
        n+WiIBECgYATmx5+Uqtyz20WpSAY5QD2A+/Jnsth3YAYThYCfoUE0dJrWxI1fmUs
        4dFt+QScfSPIWNAkPjeQinXerflrze/3FkmZ+X21fao33Ymq+RvT+O8Wsz6FmMR0
        wyEvPHSgjDQ0jEwyRd8PhhZa13Zj2XoteoBwTRea20WSKetbUxI88A==
        -----END RSA PRIVATE KEY-----
      EOH
    end
  end
end
