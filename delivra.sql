-- =====================================================================
--  DELIVRA - Plataforma de Delivery
-- =====================================================================

DROP DATABASE IF EXISTS delivra;
CREATE DATABASE delivra
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;
USE delivra;

SET time_zone = '-03:00';

-- =====================================================================
-- 1. TABELAS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 USUARIO: conta de acesso única (login) para todos os perfis
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nome           VARCHAR(120)  NOT NULL,
    email          VARCHAR(150)  NOT NULL,
    senha_hash     VARCHAR(255)  NOT NULL COMMENT 'Hash bcrypt gerado pela API',
    telefone       VARCHAR(20)   NOT NULL,
    cpf            CHAR(11)      NULL,
    tipo           ENUM('CLIENTE','LOJISTA','ENTREGADOR','ADMIN') NOT NULL,
    foto_url       VARCHAR(255)  NULL,
    ativo          TINYINT(1)    NOT NULL DEFAULT 1,
    criado_em      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario       PRIMARY KEY (id),
    CONSTRAINT uk_usuario_email UNIQUE (email),
    CONSTRAINT uk_usuario_cpf   UNIQUE (cpf)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.2 CLIENTE: especialização de USUARIO (1:1)
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
    usuario_id       INT UNSIGNED NOT NULL,
    data_nascimento  DATE         NULL,
    CONSTRAINT pk_cliente PRIMARY KEY (usuario_id),
    CONSTRAINT fk_cliente_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.3 ENTREGADOR: especialização de USUARIO (1:1)
-- ---------------------------------------------------------------------
CREATE TABLE entregador (
    usuario_id        INT UNSIGNED  NOT NULL,
    cnh               VARCHAR(11)   NULL,
    tipo_veiculo      ENUM('BICICLETA','MOTO','CARRO') NOT NULL,
    placa             VARCHAR(8)    NULL,
    disponivel        TINYINT(1)    NOT NULL DEFAULT 0,
    latitude          DECIMAL(10,7) NULL,
    longitude         DECIMAL(10,7) NULL,
    avaliacao_media   DECIMAL(3,2)  NOT NULL DEFAULT 0.00,
    total_avaliacoes  INT UNSIGNED  NOT NULL DEFAULT 0,
    total_entregas    INT UNSIGNED  NOT NULL DEFAULT 0,
    CONSTRAINT pk_entregador PRIMARY KEY (usuario_id),
    CONSTRAINT fk_entregador_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE CASCADE,
    CONSTRAINT ck_entregador_veiculo CHECK (tipo_veiculo = 'BICICLETA' OR placa IS NOT NULL)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.4 ENDERECO: endereços de entrega do cliente (1:N)
-- ---------------------------------------------------------------------
CREATE TABLE endereco (
    id           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    cliente_id   INT UNSIGNED  NOT NULL,
    apelido      VARCHAR(40)   NOT NULL DEFAULT 'Casa',
    cep          CHAR(8)       NOT NULL,
    logradouro   VARCHAR(150)  NOT NULL,
    numero       VARCHAR(10)   NOT NULL,
    complemento  VARCHAR(80)   NULL,
    bairro       VARCHAR(80)   NOT NULL,
    cidade       VARCHAR(80)   NOT NULL,
    uf           CHAR(2)       NOT NULL,
    latitude     DECIMAL(10,7) NULL,
    longitude    DECIMAL(10,7) NULL,
    principal    TINYINT(1)    NOT NULL DEFAULT 0,
    ativo        TINYINT(1)    NOT NULL DEFAULT 1,
    CONSTRAINT pk_endereco PRIMARY KEY (id),
    CONSTRAINT fk_endereco_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (usuario_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.5 CATEGORIA_ESTABELECIMENTO: Pizzaria, Lanches, Mercado, Farmácia...
-- ---------------------------------------------------------------------
CREATE TABLE categoria_estabelecimento (
    id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome      VARCHAR(60)  NOT NULL,
    icone_url VARCHAR(255) NULL,
    CONSTRAINT pk_categoria_estabelecimento PRIMARY KEY (id),
    CONSTRAINT uk_categoria_estabelecimento_nome UNIQUE (nome)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.6 ESTABELECIMENTO: loja parceira, pertence a um LOJISTA
-- ---------------------------------------------------------------------
CREATE TABLE estabelecimento (
    id                 INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    lojista_id         INT UNSIGNED  NOT NULL,
    categoria_id       INT UNSIGNED  NOT NULL,
    cnpj               CHAR(14)      NOT NULL,
    razao_social       VARCHAR(150)  NOT NULL,
    nome_fantasia      VARCHAR(100)  NOT NULL,
    descricao          VARCHAR(500)  NULL,
    telefone           VARCHAR(20)   NOT NULL,
    logo_url           VARCHAR(255)  NULL,
    cep                CHAR(8)       NOT NULL,
    logradouro         VARCHAR(150)  NOT NULL,
    numero             VARCHAR(10)   NOT NULL,
    complemento        VARCHAR(80)   NULL,
    bairro             VARCHAR(80)   NOT NULL,
    cidade             VARCHAR(80)   NOT NULL,
    uf                 CHAR(2)       NOT NULL,
    latitude           DECIMAL(10,7) NULL,
    longitude          DECIMAL(10,7) NULL,
    taxa_entrega       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    pedido_minimo      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tempo_preparo_min  SMALLINT UNSIGNED NOT NULL DEFAULT 30,
    raio_entrega_km    DECIMAL(5,2)  NOT NULL DEFAULT 5.00,
    aberto             TINYINT(1)    NOT NULL DEFAULT 0 COMMENT 'Chave manual abrir/fechar loja',
    avaliacao_media    DECIMAL(3,2)  NOT NULL DEFAULT 0.00,
    total_avaliacoes   INT UNSIGNED  NOT NULL DEFAULT 0,
    ativo              TINYINT(1)    NOT NULL DEFAULT 1,
    criado_em          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_estabelecimento PRIMARY KEY (id),
    CONSTRAINT uk_estabelecimento_cnpj UNIQUE (cnpj),
    CONSTRAINT fk_estabelecimento_lojista FOREIGN KEY (lojista_id)
        REFERENCES usuario (id),
    CONSTRAINT fk_estabelecimento_categoria FOREIGN KEY (categoria_id)
        REFERENCES categoria_estabelecimento (id),
    CONSTRAINT ck_estabelecimento_valores CHECK (taxa_entrega >= 0 AND pedido_minimo >= 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.7 HORARIO_FUNCIONAMENTO: um registro por dia da semana
--     dia_semana segue DAYOFWEEK(): 1 = domingo ... 7 = sábado
-- ---------------------------------------------------------------------
CREATE TABLE horario_funcionamento (
    id                  INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    estabelecimento_id  INT UNSIGNED     NOT NULL,
    dia_semana          TINYINT UNSIGNED NOT NULL,
    hora_abertura       TIME             NOT NULL,
    hora_fechamento     TIME             NOT NULL,
    CONSTRAINT pk_horario_funcionamento PRIMARY KEY (id),
    CONSTRAINT uk_horario_estab_dia UNIQUE (estabelecimento_id, dia_semana),
    CONSTRAINT fk_horario_estabelecimento FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id) ON DELETE CASCADE,
    CONSTRAINT ck_horario_dia CHECK (dia_semana BETWEEN 1 AND 7)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.8 CATEGORIA_PRODUTO: seções do cardápio de cada estabelecimento
-- ---------------------------------------------------------------------
CREATE TABLE categoria_produto (
    id                  INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    estabelecimento_id  INT UNSIGNED      NOT NULL,
    nome                VARCHAR(60)       NOT NULL,
    ordem               SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT pk_categoria_produto PRIMARY KEY (id),
    CONSTRAINT uk_categoria_produto UNIQUE (estabelecimento_id, nome),
    CONSTRAINT fk_categoria_produto_estab FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.9 PRODUTO: itens do cardápio
--     estoque NULL = estoque não controlado
-- ---------------------------------------------------------------------
CREATE TABLE produto (
    id                    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    estabelecimento_id    INT UNSIGNED  NOT NULL,
    categoria_produto_id  INT UNSIGNED  NULL,
    nome                  VARCHAR(100)  NOT NULL,
    descricao             VARCHAR(500)  NULL,
    preco                 DECIMAL(10,2) NOT NULL,
    preco_promocional     DECIMAL(10,2) NULL,
    imagem_url            VARCHAR(255)  NULL,
    estoque               INT           NULL,
    disponivel            TINYINT(1)    NOT NULL DEFAULT 1,
    criado_em             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_produto PRIMARY KEY (id),
    CONSTRAINT fk_produto_estabelecimento FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id),
    CONSTRAINT fk_produto_categoria FOREIGN KEY (categoria_produto_id)
        REFERENCES categoria_produto (id) ON DELETE SET NULL,
    CONSTRAINT ck_produto_preco CHECK (preco > 0),
    CONSTRAINT ck_produto_promo CHECK (preco_promocional IS NULL OR (preco_promocional > 0 AND preco_promocional < preco)),
    CONSTRAINT ck_produto_estoque CHECK (estoque IS NULL OR estoque >= 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.10 HISTORICO_PRECO_PRODUTO: alimentada por trigger
-- ---------------------------------------------------------------------
CREATE TABLE historico_preco_produto (
    id              INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    produto_id      INT UNSIGNED  NOT NULL,
    preco_anterior  DECIMAL(10,2) NOT NULL,
    preco_novo      DECIMAL(10,2) NOT NULL,
    alterado_em     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historico_preco PRIMARY KEY (id),
    CONSTRAINT fk_historico_preco_produto FOREIGN KEY (produto_id)
        REFERENCES produto (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.11 CUPOM: cupom global (estabelecimento_id NULL) ou de uma loja
-- ---------------------------------------------------------------------
CREATE TABLE cupom (
    id                   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    codigo               VARCHAR(30)   NOT NULL,
    descricao            VARCHAR(150)  NULL,
    tipo                 ENUM('PERCENTUAL','VALOR_FIXO') NOT NULL,
    valor                DECIMAL(10,2) NOT NULL,
    valor_minimo_pedido  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    desconto_maximo      DECIMAL(10,2) NULL,
    data_inicio          DATETIME      NOT NULL,
    data_fim             DATETIME      NOT NULL,
    limite_uso           INT UNSIGNED  NULL,
    quantidade_usada     INT UNSIGNED  NOT NULL DEFAULT 0,
    estabelecimento_id   INT UNSIGNED  NULL,
    ativo                TINYINT(1)    NOT NULL DEFAULT 1,
    CONSTRAINT pk_cupom PRIMARY KEY (id),
    CONSTRAINT uk_cupom_codigo UNIQUE (codigo),
    CONSTRAINT fk_cupom_estabelecimento FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id),
    CONSTRAINT ck_cupom_valor CHECK (valor > 0 AND (tipo = 'VALOR_FIXO' OR valor <= 100)),
    CONSTRAINT ck_cupom_periodo CHECK (data_fim > data_inicio)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.12 PEDIDO
-- ---------------------------------------------------------------------
CREATE TABLE pedido (
    id                   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    cliente_id           INT UNSIGNED  NOT NULL,
    estabelecimento_id   INT UNSIGNED  NOT NULL,
    entregador_id        INT UNSIGNED  NULL,
    endereco_id          INT UNSIGNED  NOT NULL,
    cupom_id             INT UNSIGNED  NULL,
    status               ENUM('AGUARDANDO_PAGAMENTO','CONFIRMADO','EM_PREPARO',
                              'PRONTO','EM_ROTA','ENTREGUE','CANCELADO')
                         NOT NULL DEFAULT 'AGUARDANDO_PAGAMENTO',
    subtotal             DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    taxa_entrega         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    desconto             DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total                DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    observacao           VARCHAR(255)  NULL,
    codigo_entrega       CHAR(4)       NULL COMMENT 'Código que o cliente informa ao entregador',
    motivo_cancelamento  VARCHAR(255)  NULL,
    criado_em            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    entregue_em          DATETIME      NULL,
    CONSTRAINT pk_pedido PRIMARY KEY (id),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (usuario_id),
    CONSTRAINT fk_pedido_estabelecimento FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id),
    CONSTRAINT fk_pedido_entregador FOREIGN KEY (entregador_id)
        REFERENCES entregador (usuario_id),
    CONSTRAINT fk_pedido_endereco FOREIGN KEY (endereco_id)
        REFERENCES endereco (id),
    CONSTRAINT fk_pedido_cupom FOREIGN KEY (cupom_id)
        REFERENCES cupom (id),
    CONSTRAINT ck_pedido_valores CHECK (subtotal >= 0 AND taxa_entrega >= 0
                                        AND desconto >= 0 AND total >= 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.13 ITEM_PEDIDO: tabela associativa PEDIDO x PRODUTO (N:N)
-- ---------------------------------------------------------------------
CREATE TABLE item_pedido (
    id              INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    pedido_id       INT UNSIGNED      NOT NULL,
    produto_id      INT UNSIGNED      NOT NULL,
    quantidade      SMALLINT UNSIGNED NOT NULL,
    preco_unitario  DECIMAL(10,2)     NOT NULL DEFAULT 0.00 COMMENT 'Preço congelado no momento da compra',
    subtotal        DECIMAL(10,2)     NOT NULL DEFAULT 0.00,
    observacao      VARCHAR(255)      NULL,
    CONSTRAINT pk_item_pedido PRIMARY KEY (id),
    CONSTRAINT fk_item_pedido_pedido FOREIGN KEY (pedido_id)
        REFERENCES pedido (id) ON DELETE CASCADE,
    CONSTRAINT fk_item_pedido_produto FOREIGN KEY (produto_id)
        REFERENCES produto (id),
    CONSTRAINT ck_item_quantidade CHECK (quantidade > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.14 PAGAMENTO: 1:1 com PEDIDO
-- ---------------------------------------------------------------------
CREATE TABLE pagamento (
    id                    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    pedido_id             INT UNSIGNED  NOT NULL,
    metodo                ENUM('PIX','CARTAO_CREDITO','CARTAO_DEBITO','DINHEIRO') NOT NULL,
    status                ENUM('PENDENTE','APROVADO','RECUSADO','ESTORNADO','CANCELADO')
                          NOT NULL DEFAULT 'PENDENTE',
    valor                 DECIMAL(10,2) NOT NULL,
    troco_para            DECIMAL(10,2) NULL,
    transacao_externa_id  VARCHAR(100)  NULL COMMENT 'ID no gateway de pagamento',
    pago_em               DATETIME      NULL,
    criado_em             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_pagamento PRIMARY KEY (id),
    CONSTRAINT uk_pagamento_pedido UNIQUE (pedido_id),
    CONSTRAINT fk_pagamento_pedido FOREIGN KEY (pedido_id)
        REFERENCES pedido (id) ON DELETE CASCADE,
    CONSTRAINT ck_pagamento_troco CHECK (troco_para IS NULL OR (metodo = 'DINHEIRO' AND troco_para >= valor))
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.15 HISTORICO_STATUS_PEDIDO: linha do tempo do pedido (via trigger)
-- ---------------------------------------------------------------------
CREATE TABLE historico_status_pedido (
    id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    pedido_id        INT UNSIGNED NOT NULL,
    status_anterior  VARCHAR(25)  NULL,
    status_novo      VARCHAR(25)  NOT NULL,
    usuario_id       INT UNSIGNED NULL COMMENT 'Quem realizou a alteração',
    alterado_em      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historico_status PRIMARY KEY (id),
    CONSTRAINT fk_historico_status_pedido FOREIGN KEY (pedido_id)
        REFERENCES pedido (id) ON DELETE CASCADE,
    CONSTRAINT fk_historico_status_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE SET NULL
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.16 AVALIACAO: uma por pedido entregue
-- ---------------------------------------------------------------------
CREATE TABLE avaliacao (
    id                        INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    pedido_id                 INT UNSIGNED     NOT NULL,
    cliente_id                INT UNSIGNED     NOT NULL,
    estabelecimento_id        INT UNSIGNED     NOT NULL,
    entregador_id             INT UNSIGNED     NULL,
    nota_estabelecimento      TINYINT UNSIGNED NOT NULL,
    nota_entregador           TINYINT UNSIGNED NULL,
    comentario                VARCHAR(500)     NULL,
    resposta_estabelecimento  VARCHAR(500)     NULL,
    criado_em                 DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_avaliacao PRIMARY KEY (id),
    CONSTRAINT uk_avaliacao_pedido UNIQUE (pedido_id),
    CONSTRAINT fk_avaliacao_pedido FOREIGN KEY (pedido_id)
        REFERENCES pedido (id),
    CONSTRAINT fk_avaliacao_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (usuario_id),
    CONSTRAINT fk_avaliacao_estabelecimento FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id),
    CONSTRAINT fk_avaliacao_entregador FOREIGN KEY (entregador_id)
        REFERENCES entregador (usuario_id),
    CONSTRAINT ck_avaliacao_notas CHECK (nota_estabelecimento BETWEEN 1 AND 5
                                         AND (nota_entregador IS NULL OR nota_entregador BETWEEN 1 AND 5))
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.17 FAVORITO: cliente x estabelecimento (N:N)
-- ---------------------------------------------------------------------
CREATE TABLE favorito (
    cliente_id          INT UNSIGNED NOT NULL,
    estabelecimento_id  INT UNSIGNED NOT NULL,
    criado_em           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_favorito PRIMARY KEY (cliente_id, estabelecimento_id),
    CONSTRAINT fk_favorito_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (usuario_id) ON DELETE CASCADE,
    CONSTRAINT fk_favorito_estabelecimento FOREIGN KEY (estabelecimento_id)
        REFERENCES estabelecimento (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 1.18 NOTIFICACAO: notificações in-app / push (geradas por triggers)
-- ---------------------------------------------------------------------
CREATE TABLE notificacao (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    usuario_id  INT UNSIGNED NOT NULL,
    pedido_id   INT UNSIGNED NULL,
    titulo      VARCHAR(100) NOT NULL,
    mensagem    VARCHAR(255) NOT NULL,
    lida        TINYINT(1)   NOT NULL DEFAULT 0,
    criado_em   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_notificacao PRIMARY KEY (id),
    CONSTRAINT fk_notificacao_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuario (id) ON DELETE CASCADE,
    CONSTRAINT fk_notificacao_pedido FOREIGN KEY (pedido_id)
        REFERENCES pedido (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- =====================================================================
-- 2. ÍNDICES (consultas mais frequentes da API / Web / Mobile)
-- =====================================================================
CREATE INDEX idx_usuario_tipo            ON usuario (tipo, ativo);
CREATE INDEX idx_endereco_cliente        ON endereco (cliente_id, ativo);
CREATE INDEX idx_estab_busca             ON estabelecimento (cidade, categoria_id, ativo);
CREATE INDEX idx_estab_nome              ON estabelecimento (nome_fantasia);
CREATE INDEX idx_produto_cardapio        ON produto (estabelecimento_id, disponivel);
CREATE INDEX idx_produto_nome            ON produto (nome);
CREATE INDEX idx_entregador_disponivel   ON entregador (disponivel);
CREATE INDEX idx_pedido_cliente_data     ON pedido (cliente_id, criado_em);
CREATE INDEX idx_pedido_estab_status     ON pedido (estabelecimento_id, status, criado_em);
CREATE INDEX idx_pedido_entregador       ON pedido (entregador_id, status);
CREATE INDEX idx_pedido_status           ON pedido (status);
CREATE INDEX idx_historico_status_pedido ON historico_status_pedido (pedido_id, alterado_em);
CREATE INDEX idx_notificacao_usuario     ON notificacao (usuario_id, lida, criado_em);
CREATE INDEX idx_cupom_validade          ON cupom (ativo, data_inicio, data_fim);

-- =====================================================================
-- 3. FUNÇÕES
-- =====================================================================
DELIMITER $$

-- Calcula o desconto de um cupom sobre um subtotal (sem validar regras)
CREATE FUNCTION fn_calcular_desconto(p_cupom_id INT UNSIGNED, p_subtotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_tipo   VARCHAR(20);
    DECLARE v_valor  DECIMAL(10,2);
    DECLARE v_maximo DECIMAL(10,2);
    DECLARE v_desc   DECIMAL(10,2) DEFAULT 0.00;

    IF p_cupom_id IS NULL THEN
        RETURN 0.00;
    END IF;

    SELECT tipo, valor, desconto_maximo
      INTO v_tipo, v_valor, v_maximo
      FROM cupom WHERE id = p_cupom_id;

    IF v_tipo = 'PERCENTUAL' THEN
        SET v_desc = ROUND(p_subtotal * v_valor / 100, 2);
    ELSE
        SET v_desc = v_valor;
    END IF;

    IF v_maximo IS NOT NULL AND v_desc > v_maximo THEN
        SET v_desc = v_maximo;
    END IF;

    RETURN LEAST(v_desc, p_subtotal);
END$$

-- Indica se o estabelecimento está dentro do horário de funcionamento
CREATE FUNCTION fn_estabelecimento_aberto(p_estab_id INT UNSIGNED, p_momento DATETIME)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_abre  TIME;
    DECLARE v_fecha TIME;
    DECLARE v_hora  TIME DEFAULT TIME(p_momento);
    DECLARE v_flag  TINYINT DEFAULT 0;

    SELECT aberto INTO v_flag FROM estabelecimento
     WHERE id = p_estab_id AND ativo = 1;
    IF v_flag IS NULL OR v_flag = 0 THEN
        RETURN 0;
    END IF;

    SELECT hora_abertura, hora_fechamento INTO v_abre, v_fecha
      FROM horario_funcionamento
     WHERE estabelecimento_id = p_estab_id
       AND dia_semana = DAYOFWEEK(p_momento)
     LIMIT 1;

    IF v_abre IS NULL THEN
        RETURN 0;
    ELSEIF v_fecha > v_abre THEN                 -- horário normal (ex.: 10h às 22h)
        RETURN IF(v_hora BETWEEN v_abre AND v_fecha, 1, 0);
    ELSE                                          -- vira a meia-noite (ex.: 18h às 02h)
        RETURN IF(v_hora >= v_abre OR v_hora <= v_fecha, 1, 0);
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- 4. TRIGGERS
-- =====================================================================
DELIMITER $$

-- T1: normaliza e-mail antes de inserir/alterar usuário
CREATE TRIGGER trg_usuario_bi BEFORE INSERT ON usuario
FOR EACH ROW
BEGIN
    SET NEW.email = LOWER(TRIM(NEW.email));
    SET NEW.nome  = TRIM(NEW.nome);
END$$

CREATE TRIGGER trg_usuario_bu BEFORE UPDATE ON usuario
FOR EACH ROW
BEGIN
    SET NEW.email = LOWER(TRIM(NEW.email));
END$$

-- T2: registra histórico sempre que o preço de um produto muda
CREATE TRIGGER trg_produto_au_historico_preco AFTER UPDATE ON produto
FOR EACH ROW
BEGIN
    IF NEW.preco <> OLD.preco THEN
        INSERT INTO historico_preco_produto (produto_id, preco_anterior, preco_novo)
        VALUES (NEW.id, OLD.preco, NEW.preco);
    END IF;
END$$

-- T3: produto com estoque zerado fica indisponível automaticamente
CREATE TRIGGER trg_produto_bu_estoque BEFORE UPDATE ON produto
FOR EACH ROW
BEGIN
    IF NEW.estoque IS NOT NULL AND NEW.estoque = 0 THEN
        SET NEW.disponivel = 0;
    ELSEIF NEW.estoque IS NOT NULL AND OLD.estoque = 0 AND NEW.estoque > 0 THEN
        SET NEW.disponivel = 1;
    END IF;
END$$

-- T4: valida o item e congela o preço do produto no pedido
CREATE TRIGGER trg_item_pedido_bi BEFORE INSERT ON item_pedido
FOR EACH ROW
BEGIN
    DECLARE v_estab_pedido  INT UNSIGNED;
    DECLARE v_estab_produto INT UNSIGNED;
    DECLARE v_disponivel    TINYINT;
    DECLARE v_estoque       INT;
    DECLARE v_preco         DECIMAL(10,2);
    DECLARE v_msg           VARCHAR(255);

    SELECT estabelecimento_id INTO v_estab_pedido FROM pedido WHERE id = NEW.pedido_id;

    SELECT estabelecimento_id, disponivel, estoque, COALESCE(preco_promocional, preco)
      INTO v_estab_produto, v_disponivel, v_estoque, v_preco
      FROM produto WHERE id = NEW.produto_id;

    IF v_estab_produto IS NULL THEN
        SET v_msg = CONCAT('Produto ', NEW.produto_id, ' não encontrado.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_estab_produto <> v_estab_pedido THEN
        SET v_msg = CONCAT('Produto ', NEW.produto_id, ' não pertence ao estabelecimento do pedido.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_disponivel = 0 THEN
        SET v_msg = CONCAT('Produto ', NEW.produto_id, ' indisponível no momento.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_estoque IS NOT NULL AND v_estoque < NEW.quantidade THEN
        SET v_msg = CONCAT('Estoque insuficiente para o produto ', NEW.produto_id,
                           ' (disponível: ', v_estoque, ').');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SET NEW.preco_unitario = v_preco;
    SET NEW.subtotal       = ROUND(v_preco * NEW.quantidade, 2);
END$$

-- T5: baixa de estoque após inserir o item
CREATE TRIGGER trg_item_pedido_ai AFTER INSERT ON item_pedido
FOR EACH ROW
BEGIN
    UPDATE produto
       SET estoque = estoque - NEW.quantidade
     WHERE id = NEW.produto_id
       AND estoque IS NOT NULL;
END$$

-- T6: valores iniciais do pedido (código de entrega e status)
CREATE TRIGGER trg_pedido_bi BEFORE INSERT ON pedido
FOR EACH ROW
BEGIN
    SET NEW.status         = 'AGUARDANDO_PAGAMENTO';
    SET NEW.codigo_entrega = LPAD(FLOOR(RAND() * 10000), 4, '0');
    SET NEW.total          = NEW.subtotal + NEW.taxa_entrega - NEW.desconto;
END$$

-- T7: após criar o pedido -> histórico, uso do cupom e aviso ao lojista
CREATE TRIGGER trg_pedido_ai AFTER INSERT ON pedido
FOR EACH ROW
BEGIN
    INSERT INTO historico_status_pedido (pedido_id, status_anterior, status_novo, usuario_id)
    VALUES (NEW.id, NULL, NEW.status, NEW.cliente_id);

    IF NEW.cupom_id IS NOT NULL THEN
        UPDATE cupom SET quantidade_usada = quantidade_usada + 1 WHERE id = NEW.cupom_id;
    END IF;

    INSERT INTO notificacao (usuario_id, pedido_id, titulo, mensagem)
    SELECT e.lojista_id, NEW.id, 'Novo pedido',
           CONCAT('Você recebeu o pedido #', NEW.id, '.')
      FROM estabelecimento e WHERE e.id = NEW.estabelecimento_id;
END$$

-- T8: máquina de estados do pedido (impede transições inválidas)
CREATE TRIGGER trg_pedido_bu BEFORE UPDATE ON pedido
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(255);

    IF NEW.status <> OLD.status THEN
        IF NOT (
               (OLD.status = 'AGUARDANDO_PAGAMENTO' AND NEW.status IN ('CONFIRMADO','CANCELADO'))
            OR (OLD.status = 'CONFIRMADO'           AND NEW.status IN ('EM_PREPARO','CANCELADO'))
            OR (OLD.status = 'EM_PREPARO'           AND NEW.status IN ('PRONTO','CANCELADO'))
            OR (OLD.status = 'PRONTO'               AND NEW.status IN ('EM_ROTA','CANCELADO'))
            OR (OLD.status = 'EM_ROTA'              AND NEW.status = 'ENTREGUE')
        ) THEN
            SET v_msg = CONCAT('Transição de status inválida: ', OLD.status, ' -> ', NEW.status, '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF NEW.status = 'EM_ROTA' AND NEW.entregador_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Pedido precisa de um entregador para sair para entrega.';
        END IF;

        IF NEW.status = 'ENTREGUE' THEN
            SET NEW.entregue_em = NOW();
        END IF;

        IF NEW.status = 'CANCELADO' AND NEW.motivo_cancelamento IS NULL THEN
            SET NEW.motivo_cancelamento = 'Não informado';
        END IF;
    END IF;

    -- pedidos finalizados não podem ter valores alterados
    IF OLD.status IN ('ENTREGUE','CANCELADO') AND NEW.total <> OLD.total THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pedido finalizado não pode ser alterado.';
    END IF;

    SET NEW.total = NEW.subtotal + NEW.taxa_entrega - NEW.desconto;
END$$

-- T9: efeitos da mudança de status (histórico, notificações, estoque,
--     pagamento, cupom e disponibilidade do entregador)
CREATE TRIGGER trg_pedido_au AFTER UPDATE ON pedido
FOR EACH ROW
BEGIN
    -- entregador aceitou a corrida
    IF NEW.entregador_id IS NOT NULL AND OLD.entregador_id IS NULL THEN
        UPDATE entregador SET disponivel = 0 WHERE usuario_id = NEW.entregador_id;
        INSERT INTO notificacao (usuario_id, pedido_id, titulo, mensagem)
        VALUES (NEW.entregador_id, NEW.id, 'Entrega atribuída',
                CONCAT('Você aceitou a entrega do pedido #', NEW.id, '.'));
    END IF;

    IF NEW.status <> OLD.status THEN
        INSERT INTO historico_status_pedido (pedido_id, status_anterior, status_novo, usuario_id)
        VALUES (NEW.id, OLD.status, NEW.status, @usuario_id);

        INSERT INTO notificacao (usuario_id, pedido_id, titulo, mensagem)
        VALUES (NEW.cliente_id, NEW.id,
                CONCAT('Pedido #', NEW.id),
                CASE NEW.status
                    WHEN 'CONFIRMADO' THEN 'Pedido confirmado! A loja já recebeu seu pedido.'
                    WHEN 'EM_PREPARO' THEN 'Seu pedido está sendo preparado.'
                    WHEN 'PRONTO'     THEN 'Seu pedido está pronto e aguardando o entregador.'
                    WHEN 'EM_ROTA'    THEN CONCAT('Saiu para entrega! Código de entrega: ', NEW.codigo_entrega)
                    WHEN 'ENTREGUE'   THEN 'Pedido entregue. Que tal avaliar sua experiência?'
                    WHEN 'CANCELADO'  THEN CONCAT('Pedido cancelado: ', NEW.motivo_cancelamento)
                END);

        IF NEW.status = 'ENTREGUE' THEN
            UPDATE entregador
               SET disponivel = 1, total_entregas = total_entregas + 1
             WHERE usuario_id = NEW.entregador_id;
        END IF;

        IF NEW.status = 'CANCELADO' THEN
            -- devolve o estoque
            UPDATE produto p
              JOIN item_pedido i ON i.produto_id = p.id
               SET p.estoque = p.estoque + i.quantidade
             WHERE i.pedido_id = NEW.id
               AND p.estoque IS NOT NULL;
            -- libera o entregador
            IF NEW.entregador_id IS NOT NULL THEN
                UPDATE entregador SET disponivel = 1 WHERE usuario_id = NEW.entregador_id;
            END IF;
            -- estorna / cancela o pagamento
            UPDATE pagamento
               SET status = IF(status = 'APROVADO', 'ESTORNADO', 'CANCELADO')
             WHERE pedido_id = NEW.id
               AND status IN ('PENDENTE','APROVADO');
            -- devolve o uso do cupom
            IF NEW.cupom_id IS NOT NULL THEN
                UPDATE cupom SET quantidade_usada = quantidade_usada - 1
                 WHERE id = NEW.cupom_id AND quantidade_usada > 0;
            END IF;
        END IF;
    END IF;
END$$

-- T10: valida a avaliação e completa estabelecimento/entregador
CREATE TRIGGER trg_avaliacao_bi BEFORE INSERT ON avaliacao
FOR EACH ROW
BEGIN
    DECLARE v_status     VARCHAR(25);
    DECLARE v_cliente    INT UNSIGNED;
    DECLARE v_estab      INT UNSIGNED;
    DECLARE v_entregador INT UNSIGNED;

    SELECT status, cliente_id, estabelecimento_id, entregador_id
      INTO v_status, v_cliente, v_estab, v_entregador
      FROM pedido WHERE id = NEW.pedido_id;

    IF v_status IS NULL OR v_status <> 'ENTREGUE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Só é possível avaliar pedidos entregues.';
    END IF;
    IF v_cliente <> NEW.cliente_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Este pedido não pertence ao cliente informado.';
    END IF;

    SET NEW.estabelecimento_id = v_estab;
    SET NEW.entregador_id      = v_entregador;
    IF v_entregador IS NULL THEN
        SET NEW.nota_entregador = NULL;
    END IF;
END$$

-- T11: recalcula a média de avaliações da loja e do entregador
CREATE TRIGGER trg_avaliacao_ai AFTER INSERT ON avaliacao
FOR EACH ROW
BEGIN
    UPDATE estabelecimento e
       SET e.avaliacao_media  = (SELECT ROUND(AVG(nota_estabelecimento), 2)
                                   FROM avaliacao WHERE estabelecimento_id = NEW.estabelecimento_id),
           e.total_avaliacoes = (SELECT COUNT(*)
                                   FROM avaliacao WHERE estabelecimento_id = NEW.estabelecimento_id)
     WHERE e.id = NEW.estabelecimento_id;

    IF NEW.entregador_id IS NOT NULL AND NEW.nota_entregador IS NOT NULL THEN
        UPDATE entregador g
           SET g.avaliacao_media  = (SELECT ROUND(AVG(nota_entregador), 2) FROM avaliacao
                                      WHERE entregador_id = NEW.entregador_id AND nota_entregador IS NOT NULL),
               g.total_avaliacoes = (SELECT COUNT(*) FROM avaliacao
                                      WHERE entregador_id = NEW.entregador_id AND nota_entregador IS NOT NULL)
         WHERE g.usuario_id = NEW.entregador_id;
    END IF;

    INSERT INTO notificacao (usuario_id, pedido_id, titulo, mensagem)
    SELECT e.lojista_id, NEW.pedido_id, 'Nova avaliação',
           CONCAT('Pedido #', NEW.pedido_id, ' recebeu nota ', NEW.nota_estabelecimento, '.')
      FROM estabelecimento e WHERE e.id = NEW.estabelecimento_id;
END$$

DELIMITER ;

-- =====================================================================
-- 5. STORED PROCEDURES
-- =====================================================================
DELIMITER $$

-- P1: cadastro de cliente (usuario + cliente) em uma transação
CREATE PROCEDURE sp_cadastrar_cliente(
    IN  p_nome            VARCHAR(120),
    IN  p_email           VARCHAR(150),
    IN  p_senha_hash      VARCHAR(255),
    IN  p_telefone        VARCHAR(20),
    IN  p_cpf             CHAR(11),
    IN  p_data_nascimento DATE,
    OUT p_cliente_id      INT UNSIGNED)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF EXISTS (SELECT 1 FROM usuario WHERE email = LOWER(TRIM(p_email))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'E-mail já cadastrado.';
    END IF;

    START TRANSACTION;
        INSERT INTO usuario (nome, email, senha_hash, telefone, cpf, tipo)
        VALUES (p_nome, p_email, p_senha_hash, p_telefone, p_cpf, 'CLIENTE');
        SET p_cliente_id = LAST_INSERT_ID();
        INSERT INTO cliente (usuario_id, data_nascimento) VALUES (p_cliente_id, p_data_nascimento);
    COMMIT;
END$$

-- P2: cadastro de entregador (usuario + entregador)
CREATE PROCEDURE sp_cadastrar_entregador(
    IN  p_nome          VARCHAR(120),
    IN  p_email         VARCHAR(150),
    IN  p_senha_hash    VARCHAR(255),
    IN  p_telefone      VARCHAR(20),
    IN  p_cpf           CHAR(11),
    IN  p_cnh           VARCHAR(11),
    IN  p_tipo_veiculo  VARCHAR(10),
    IN  p_placa         VARCHAR(8),
    OUT p_entregador_id INT UNSIGNED)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_tipo_veiculo IN ('MOTO','CARRO') AND (p_cnh IS NULL OR p_placa IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CNH e placa são obrigatórias para moto ou carro.';
    END IF;

    START TRANSACTION;
        INSERT INTO usuario (nome, email, senha_hash, telefone, cpf, tipo)
        VALUES (p_nome, p_email, p_senha_hash, p_telefone, p_cpf, 'ENTREGADOR');
        SET p_entregador_id = LAST_INSERT_ID();
        INSERT INTO entregador (usuario_id, cnh, tipo_veiculo, placa)
        VALUES (p_entregador_id, p_cnh, p_tipo_veiculo, p_placa);
    COMMIT;
END$$

-- P3: adiciona endereço; se principal, desmarca os demais
CREATE PROCEDURE sp_adicionar_endereco(
    IN  p_cliente_id  INT UNSIGNED,
    IN  p_apelido     VARCHAR(40),
    IN  p_cep         CHAR(8),
    IN  p_logradouro  VARCHAR(150),
    IN  p_numero      VARCHAR(10),
    IN  p_complemento VARCHAR(80),
    IN  p_bairro      VARCHAR(80),
    IN  p_cidade      VARCHAR(80),
    IN  p_uf          CHAR(2),
    IN  p_latitude    DECIMAL(10,7),
    IN  p_longitude   DECIMAL(10,7),
    IN  p_principal   TINYINT,
    OUT p_endereco_id INT UNSIGNED)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        -- primeiro endereço do cliente é sempre o principal
        IF NOT EXISTS (SELECT 1 FROM endereco WHERE cliente_id = p_cliente_id AND ativo = 1) THEN
            SET p_principal = 1;
        END IF;
        IF p_principal = 1 THEN
            UPDATE endereco SET principal = 0 WHERE cliente_id = p_cliente_id;
        END IF;

        INSERT INTO endereco (cliente_id, apelido, cep, logradouro, numero, complemento,
                              bairro, cidade, uf, latitude, longitude, principal)
        VALUES (p_cliente_id, COALESCE(p_apelido, 'Casa'), p_cep, p_logradouro, p_numero,
                p_complemento, p_bairro, p_cidade, UPPER(p_uf), p_latitude, p_longitude,
                COALESCE(p_principal, 0));
        SET p_endereco_id = LAST_INSERT_ID();
    COMMIT;
END$$

-- P4: cria o pedido completo (itens em JSON) em uma única transação
--     p_itens: '[{"produto_id":1,"quantidade":2,"observacao":"sem cebola"}, ...]'
CREATE PROCEDURE sp_criar_pedido(
    IN  p_cliente_id         INT UNSIGNED,
    IN  p_estabelecimento_id INT UNSIGNED,
    IN  p_endereco_id        INT UNSIGNED,
    IN  p_metodo_pagamento   VARCHAR(20),
    IN  p_troco_para         DECIMAL(10,2),
    IN  p_codigo_cupom       VARCHAR(30),
    IN  p_observacao         VARCHAR(255),
    IN  p_itens              JSON,
    OUT p_pedido_id          INT UNSIGNED)
BEGIN
    DECLARE v_taxa       DECIMAL(10,2);
    DECLARE v_minimo     DECIMAL(10,2);
    DECLARE v_aberto     TINYINT;
    DECLARE v_cupom_id   INT UNSIGNED DEFAULT NULL;
    DECLARE v_cupom_min  DECIMAL(10,2) DEFAULT 0;
    DECLARE v_subtotal   DECIMAL(10,2);
    DECLARE v_desconto   DECIMAL(10,2) DEFAULT 0;
    DECLARE v_msg        VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @usuario_id = NULL;
        RESIGNAL;
    END;

    -- validações
    IF NOT EXISTS (SELECT 1 FROM cliente c JOIN usuario u ON u.id = c.usuario_id
                    WHERE c.usuario_id = p_cliente_id AND u.ativo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente inexistente ou inativo.';
    END IF;

    SELECT taxa_entrega, pedido_minimo, aberto
      INTO v_taxa, v_minimo, v_aberto
      FROM estabelecimento WHERE id = p_estabelecimento_id AND ativo = 1;
    IF v_aberto IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estabelecimento inexistente ou inativo.';
    ELSEIF v_aberto = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estabelecimento fechado no momento.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM endereco WHERE id = p_endereco_id
                      AND cliente_id = p_cliente_id AND ativo = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Endereço inválido para este cliente.';
    END IF;

    IF p_itens IS NULL OR JSON_LENGTH(p_itens) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O pedido precisa ter ao menos um item.';
    END IF;

    IF p_codigo_cupom IS NOT NULL AND p_codigo_cupom <> '' THEN
        SELECT id, valor_minimo_pedido INTO v_cupom_id, v_cupom_min
          FROM cupom
         WHERE codigo = UPPER(p_codigo_cupom)
           AND ativo = 1
           AND NOW() BETWEEN data_inicio AND data_fim
           AND (limite_uso IS NULL OR quantidade_usada < limite_uso)
           AND (estabelecimento_id IS NULL OR estabelecimento_id = p_estabelecimento_id);
        IF v_cupom_id IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cupom inválido, expirado ou esgotado.';
        END IF;
    END IF;

    SET @usuario_id = p_cliente_id;

    START TRANSACTION;
        INSERT INTO pedido (cliente_id, estabelecimento_id, endereco_id, cupom_id,
                            taxa_entrega, observacao)
        VALUES (p_cliente_id, p_estabelecimento_id, p_endereco_id, v_cupom_id,
                v_taxa, p_observacao);
        SET p_pedido_id = LAST_INSERT_ID();

        -- itens: preço, validação e baixa de estoque feitos pelas triggers
        INSERT INTO item_pedido (pedido_id, produto_id, quantidade, observacao)
        SELECT p_pedido_id, j.produto_id, j.quantidade, j.observacao
          FROM JSON_TABLE(p_itens, '$[*]' COLUMNS (
                    produto_id INT          PATH '$.produto_id',
                    quantidade INT          PATH '$.quantidade',
                    observacao VARCHAR(255) PATH '$.observacao'
               )) AS j;

        SELECT SUM(subtotal) INTO v_subtotal FROM item_pedido WHERE pedido_id = p_pedido_id;

        IF v_subtotal < v_minimo THEN
            SET v_msg = CONCAT('Pedido mínimo desta loja é R$ ', FORMAT(v_minimo, 2, 'pt_BR'), '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF v_cupom_id IS NOT NULL THEN
            IF v_subtotal < v_cupom_min THEN
                SET v_msg = CONCAT('Cupom válido para pedidos a partir de R$ ', FORMAT(v_cupom_min, 2, 'pt_BR'), '.');
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
            END IF;
            SET v_desconto = fn_calcular_desconto(v_cupom_id, v_subtotal);
        END IF;

        UPDATE pedido
           SET subtotal = v_subtotal,
               desconto = v_desconto
         WHERE id = p_pedido_id;            -- total é recalculado pela trigger

        INSERT INTO pagamento (pedido_id, metodo, valor, troco_para)
        SELECT id, p_metodo_pagamento, total,
               IF(p_metodo_pagamento = 'DINHEIRO', p_troco_para, NULL)
          FROM pedido WHERE id = p_pedido_id;

        -- dinheiro é pago na entrega: pedido já segue confirmado
        IF p_metodo_pagamento = 'DINHEIRO' THEN
            UPDATE pedido SET status = 'CONFIRMADO' WHERE id = p_pedido_id;
        END IF;
    COMMIT;

    SET @usuario_id = NULL;
END$$

-- P5: retorno do gateway de pagamento (webhook da API)
CREATE PROCEDURE sp_confirmar_pagamento(
    IN p_pedido_id     INT UNSIGNED,
    IN p_aprovado      TINYINT,
    IN p_transacao_id  VARCHAR(100))
BEGIN
    DECLARE v_status_pag VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT status INTO v_status_pag FROM pagamento WHERE pedido_id = p_pedido_id;
    IF v_status_pag IS NULL OR v_status_pag <> 'PENDENTE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não há pagamento pendente para este pedido.';
    END IF;

    SET @usuario_id = NULL;   -- alteração feita pelo sistema
    START TRANSACTION;
        IF p_aprovado = 1 THEN
            UPDATE pagamento
               SET status = 'APROVADO', pago_em = NOW(), transacao_externa_id = p_transacao_id
             WHERE pedido_id = p_pedido_id;
            UPDATE pedido SET status = 'CONFIRMADO' WHERE id = p_pedido_id;
        ELSE
            UPDATE pagamento
               SET status = 'RECUSADO', transacao_externa_id = p_transacao_id
             WHERE pedido_id = p_pedido_id;
            UPDATE pedido
               SET status = 'CANCELADO', motivo_cancelamento = 'Pagamento recusado'
             WHERE id = p_pedido_id;
        END IF;
    COMMIT;
END$$

-- P6: atualização de status pelo lojista/entregador/admin
CREATE PROCEDURE sp_atualizar_status_pedido(
    IN p_pedido_id   INT UNSIGNED,
    IN p_novo_status VARCHAR(25),
    IN p_usuario_id  INT UNSIGNED)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @usuario_id = NULL;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id = p_pedido_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pedido não encontrado.';
    END IF;

    SET @usuario_id = p_usuario_id;
    UPDATE pedido SET status = p_novo_status WHERE id = p_pedido_id;  -- regras na trigger
    SET @usuario_id = NULL;
END$$

-- P7: entregador aceita uma entrega
CREATE PROCEDURE sp_aceitar_entrega(
    IN p_pedido_id     INT UNSIGNED,
    IN p_entregador_id INT UNSIGNED)
BEGIN
    DECLARE v_disponivel TINYINT;
    DECLARE v_status     VARCHAR(25);
    DECLARE v_atual      INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        -- FOR UPDATE evita que dois entregadores peguem o mesmo pedido
        SELECT status, entregador_id INTO v_status, v_atual
          FROM pedido WHERE id = p_pedido_id FOR UPDATE;
        SELECT disponivel INTO v_disponivel
          FROM entregador WHERE usuario_id = p_entregador_id FOR UPDATE;

        IF v_disponivel IS NULL OR v_disponivel = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Entregador indisponível.';
        END IF;
        IF v_atual IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pedido já possui entregador.';
        END IF;
        IF v_status NOT IN ('CONFIRMADO','EM_PREPARO','PRONTO') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pedido não está disponível para entrega.';
        END IF;

        UPDATE pedido SET entregador_id = p_entregador_id WHERE id = p_pedido_id;
    COMMIT;
END$$

-- P8: entregador finaliza a entrega validando o código do cliente
CREATE PROCEDURE sp_finalizar_entrega(
    IN p_pedido_id      INT UNSIGNED,
    IN p_entregador_id  INT UNSIGNED,
    IN p_codigo_entrega CHAR(4))
BEGIN
    DECLARE v_codigo     CHAR(4);
    DECLARE v_entregador INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @usuario_id = NULL;
        RESIGNAL;
    END;

    SELECT codigo_entrega, entregador_id INTO v_codigo, v_entregador
      FROM pedido WHERE id = p_pedido_id;

    IF v_entregador IS NULL OR v_entregador <> p_entregador_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pedido não está atribuído a este entregador.';
    END IF;
    IF v_codigo <> p_codigo_entrega THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Código de entrega incorreto.';
    END IF;

    SET @usuario_id = p_entregador_id;
    START TRANSACTION;
        UPDATE pedido SET status = 'ENTREGUE' WHERE id = p_pedido_id;
        -- pagamento em dinheiro é recebido na entrega
        UPDATE pagamento SET status = 'APROVADO', pago_em = NOW()
         WHERE pedido_id = p_pedido_id AND metodo = 'DINHEIRO' AND status = 'PENDENTE';
    COMMIT;
    SET @usuario_id = NULL;
END$$

-- P9: cancelamento (cliente, lojista ou admin)
CREATE PROCEDURE sp_cancelar_pedido(
    IN p_pedido_id  INT UNSIGNED,
    IN p_usuario_id INT UNSIGNED,
    IN p_motivo     VARCHAR(255))
BEGIN
    DECLARE v_status  VARCHAR(25);
    DECLARE v_cliente INT UNSIGNED;
    DECLARE v_lojista INT UNSIGNED;
    DECLARE v_tipo    VARCHAR(15);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @usuario_id = NULL;
        RESIGNAL;
    END;

    SELECT p.status, p.cliente_id, e.lojista_id INTO v_status, v_cliente, v_lojista
      FROM pedido p JOIN estabelecimento e ON e.id = p.estabelecimento_id
     WHERE p.id = p_pedido_id;
    SELECT tipo INTO v_tipo FROM usuario WHERE id = p_usuario_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pedido não encontrado.';
    END IF;
    IF NOT (v_tipo = 'ADMIN' OR p_usuario_id = v_cliente OR p_usuario_id = v_lojista) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuário sem permissão para cancelar este pedido.';
    END IF;
    -- o cliente só cancela antes de a loja começar o preparo
    IF p_usuario_id = v_cliente AND v_tipo <> 'ADMIN'
       AND v_status NOT IN ('AGUARDANDO_PAGAMENTO','CONFIRMADO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O pedido já está em preparo e não pode ser cancelado pelo cliente.';
    END IF;

    SET @usuario_id = p_usuario_id;
    UPDATE pedido
       SET status = 'CANCELADO', motivo_cancelamento = COALESCE(p_motivo, 'Não informado')
     WHERE id = p_pedido_id;     -- estorno, estoque e cupom tratados na trigger
    SET @usuario_id = NULL;
END$$

-- P10: avaliação do pedido
CREATE PROCEDURE sp_avaliar_pedido(
    IN p_pedido_id            INT UNSIGNED,
    IN p_cliente_id           INT UNSIGNED,
    IN p_nota_estabelecimento TINYINT,
    IN p_nota_entregador      TINYINT,
    IN p_comentario           VARCHAR(500))
BEGIN
    IF EXISTS (SELECT 1 FROM avaliacao WHERE pedido_id = p_pedido_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Este pedido já foi avaliado.';
    END IF;

    -- estabelecimento_id é preenchido pela trigger trg_avaliacao_bi
    INSERT INTO avaliacao (pedido_id, cliente_id, estabelecimento_id,
                           nota_estabelecimento, nota_entregador, comentario)
    VALUES (p_pedido_id, p_cliente_id, 0,
            p_nota_estabelecimento, p_nota_entregador, p_comentario);
END$$

-- P11: busca de estabelecimentos para a tela inicial (Web/Mobile)
CREATE PROCEDURE sp_buscar_estabelecimentos(
    IN p_cidade       VARCHAR(80),
    IN p_categoria_id INT UNSIGNED,
    IN p_termo        VARCHAR(100))
BEGIN
    SELECT e.id,
           e.nome_fantasia,
           c.nome                     AS categoria,
           e.logo_url,
           e.bairro,
           e.taxa_entrega,
           e.pedido_minimo,
           e.tempo_preparo_min,
           e.avaliacao_media,
           e.total_avaliacoes,
           fn_estabelecimento_aberto(e.id, NOW()) AS aberto_agora
      FROM estabelecimento e
      JOIN categoria_estabelecimento c ON c.id = e.categoria_id
     WHERE e.ativo = 1
       AND (p_cidade       IS NULL OR e.cidade = p_cidade)
       AND (p_categoria_id IS NULL OR e.categoria_id = p_categoria_id)
       AND (p_termo IS NULL
            OR e.nome_fantasia LIKE CONCAT('%', p_termo, '%')
            OR EXISTS (SELECT 1 FROM produto pr
                        WHERE pr.estabelecimento_id = e.id AND pr.disponivel = 1
                          AND pr.nome LIKE CONCAT('%', p_termo, '%')))
     ORDER BY aberto_agora DESC, e.avaliacao_media DESC, e.nome_fantasia;
END$$

-- P12: relatório de vendas do estabelecimento (painel do lojista)
CREATE PROCEDURE sp_relatorio_vendas(
    IN p_estabelecimento_id INT UNSIGNED,
    IN p_data_inicio        DATE,
    IN p_data_fim           DATE)
BEGIN
    -- 1) resumo do período
    SELECT COUNT(*)                                              AS total_pedidos,
           SUM(status = 'ENTREGUE')                              AS pedidos_entregues,
           SUM(status = 'CANCELADO')                             AS pedidos_cancelados,
           COALESCE(SUM(IF(status = 'ENTREGUE', total, 0)), 0)   AS faturamento,
           COALESCE(ROUND(AVG(IF(status = 'ENTREGUE', total, NULL)), 2), 0) AS ticket_medio
      FROM pedido
     WHERE estabelecimento_id = p_estabelecimento_id
       AND DATE(criado_em) BETWEEN p_data_inicio AND p_data_fim;

    -- 2) produtos mais vendidos
    SELECT pr.id, pr.nome,
           SUM(i.quantidade) AS quantidade_vendida,
           SUM(i.subtotal)   AS receita
      FROM item_pedido i
      JOIN pedido  p  ON p.id  = i.pedido_id
      JOIN produto pr ON pr.id = i.produto_id
     WHERE p.estabelecimento_id = p_estabelecimento_id
       AND p.status = 'ENTREGUE'
       AND DATE(p.criado_em) BETWEEN p_data_inicio AND p_data_fim
     GROUP BY pr.id, pr.nome
     ORDER BY quantidade_vendida DESC
     LIMIT 10;

    -- 3) vendas por dia
    SELECT DATE(criado_em) AS dia,
           COUNT(*)        AS pedidos,
           SUM(total)      AS faturamento
      FROM pedido
     WHERE estabelecimento_id = p_estabelecimento_id
       AND status = 'ENTREGUE'
       AND DATE(criado_em) BETWEEN p_data_inicio AND p_data_fim
     GROUP BY DATE(criado_em)
     ORDER BY dia;
END$$

DELIMITER ;

-- =====================================================================
-- 6. VIEWS (consultas prontas para a API)
-- =====================================================================

-- Cardápio público de cada estabelecimento
CREATE VIEW vw_cardapio AS
SELECT p.id                                   AS produto_id,
       p.estabelecimento_id,
       e.nome_fantasia                        AS estabelecimento,
       COALESCE(c.nome, 'Outros')             AS categoria,
       COALESCE(c.ordem, 999)                 AS ordem_categoria,
       p.nome,
       p.descricao,
       p.preco,
       p.preco_promocional,
       COALESCE(p.preco_promocional, p.preco) AS preco_final,
       p.imagem_url
  FROM produto p
  JOIN estabelecimento e ON e.id = p.estabelecimento_id
  LEFT JOIN categoria_produto c ON c.id = p.categoria_produto_id
 WHERE p.disponivel = 1
   AND e.ativo = 1;

-- Pedidos com dados de cliente, loja, entregador, endereço e pagamento
CREATE VIEW vw_pedidos_detalhados AS
SELECT p.id                    AS pedido_id,
       p.status,
       p.criado_em,
       p.entregue_em,
       p.cliente_id,
       uc.nome                 AS cliente,
       uc.telefone             AS telefone_cliente,
       p.estabelecimento_id,
       e.nome_fantasia         AS estabelecimento,
       p.entregador_id,
       ue.nome                 AS entregador,
       CONCAT(en.logradouro, ', ', en.numero,
              COALESCE(CONCAT(' - ', en.complemento), ''),
              ' - ', en.bairro, ', ', en.cidade, '/', en.uf) AS endereco_entrega,
       p.subtotal,
       p.taxa_entrega,
       p.desconto,
       p.total,
       pg.metodo               AS metodo_pagamento,
       pg.status               AS status_pagamento,
       (SELECT SUM(i.quantidade) FROM item_pedido i WHERE i.pedido_id = p.id) AS qtd_itens
  FROM pedido p
  JOIN usuario         uc ON uc.id = p.cliente_id
  JOIN estabelecimento e  ON e.id  = p.estabelecimento_id
  JOIN endereco        en ON en.id = p.endereco_id
  LEFT JOIN usuario    ue ON ue.id = p.entregador_id
  LEFT JOIN pagamento  pg ON pg.pedido_id = p.id;

-- Fila de pedidos disponíveis para os entregadores
CREATE VIEW vw_entregas_disponiveis AS
SELECT p.id AS pedido_id,
       p.status,
       e.nome_fantasia AS estabelecimento,
       CONCAT(e.logradouro, ', ', e.numero, ' - ', e.bairro) AS endereco_coleta,
       e.latitude  AS lat_coleta,
       e.longitude AS lng_coleta,
       CONCAT(en.logradouro, ', ', en.numero, ' - ', en.bairro) AS endereco_entrega,
       en.latitude  AS lat_entrega,
       en.longitude AS lng_entrega,
       p.taxa_entrega,
       p.criado_em
  FROM pedido p
  JOIN estabelecimento e ON e.id = p.estabelecimento_id
  JOIN endereco en       ON en.id = p.endereco_id
 WHERE p.entregador_id IS NULL
   AND p.status IN ('CONFIRMADO','EM_PREPARO','PRONTO');

-- =====================================================================
-- 7. USUÁRIO DE BANCO DA APLICAÇÃO (API REST)
--    Troque a senha antes de usar em produção.
-- =====================================================================
DROP USER IF EXISTS 'delivra_api'@'%';
CREATE USER 'delivra_api'@'%' IDENTIFIED BY 'Troque#Esta#Senha2026';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON delivra.* TO 'delivra_api'@'%';
FLUSH PRIVILEGES;

-- =====================================================================
-- 8. DADOS INICIAIS (carga para desenvolvimento e testes)
--    senha_hash abaixo = bcrypt de "delivra123" (exemplo)
-- =====================================================================
SET @hash = '$2b$10$7EqJtq98hPqEX7fNZaFWoOhi5BWX4Z3e1Wkq2xY0yQh1u3Q8bYc5e';

INSERT INTO categoria_estabelecimento (nome) VALUES
 ('Lanches'), ('Pizzaria'), ('Japonesa'), ('Mercado'), ('Farmácia'), ('Doces e Bolos'), ('Bebidas');

INSERT INTO usuario (id, nome, email, senha_hash, telefone, cpf, tipo) VALUES
 (1, 'Administrador Delivra', 'admin@delivra.com.br',      @hash, '11900000000', NULL,          'ADMIN'),
 (2, 'Carlos Mendes',         'carlos@burgerhouse.com.br', @hash, '11911111111', '11111111111', 'LOJISTA'),
 (3, 'Fernanda Lima',         'fernanda@pizzanapoli.com',  @hash, '11922222222', '22222222222', 'LOJISTA');

INSERT INTO estabelecimento (id, lojista_id, categoria_id, cnpj, razao_social, nome_fantasia, descricao,
        telefone, cep, logradouro, numero, bairro, cidade, uf, latitude, longitude,
        taxa_entrega, pedido_minimo, tempo_preparo_min, aberto) VALUES
 (1, 2, 1, '12345678000101', 'Burger House Alimentos LTDA', 'Burger House',
  'Hambúrgueres artesanais na brasa.', '1133331111', '01310100', 'Av. Paulista', '1500',
  'Bela Vista', 'São Paulo', 'SP', -23.5614000, -46.6559000, 6.90, 25.00, 30, 1),
 (2, 3, 2, '98765432000102', 'Pizzaria Napoli ME', 'Pizza Napoli',
  'Pizzas no forno a lenha.', '1133332222', '01414001', 'Rua Haddock Lobo', '320',
  'Cerqueira César', 'São Paulo', 'SP', -23.5580000, -46.6630000, 8.00, 40.00, 45, 1);

INSERT INTO horario_funcionamento (estabelecimento_id, dia_semana, hora_abertura, hora_fechamento) VALUES
 (1,1,'11:00','23:00'),(1,2,'11:00','23:00'),(1,3,'11:00','23:00'),(1,4,'11:00','23:00'),
 (1,5,'11:00','23:00'),(1,6,'11:00','23:59'),(1,7,'11:00','23:59'),
 (2,1,'18:00','01:00'),(2,3,'18:00','23:30'),(2,4,'18:00','23:30'),(2,5,'18:00','23:30'),
 (2,6,'18:00','01:00'),(2,7,'18:00','01:00');

INSERT INTO categoria_produto (id, estabelecimento_id, nome, ordem) VALUES
 (1, 1, 'Hambúrgueres', 1), (2, 1, 'Acompanhamentos', 2), (3, 1, 'Bebidas', 3),
 (4, 2, 'Pizzas Salgadas', 1), (5, 2, 'Pizzas Doces', 2), (6, 2, 'Bebidas', 3);

INSERT INTO produto (id, estabelecimento_id, categoria_produto_id, nome, descricao, preco, preco_promocional, estoque) VALUES
 (1,  1, 1, 'Classic Burger',   'Pão brioche, blend 180g, queijo cheddar e molho da casa.', 32.90, NULL,  NULL),
 (2,  1, 1, 'Bacon Burger',     'Blend 180g, bacon crocante, cheddar e cebola caramelizada.', 38.90, 34.90, NULL),
 (3,  1, 1, 'Veggie Burger',    'Hambúrguer de grão-de-bico, rúcula e tomate.',             34.90, NULL,  NULL),
 (4,  1, 2, 'Batata Frita',     'Porção 300g com páprica.',                                  18.00, NULL,  NULL),
 (5,  1, 2, 'Onion Rings',      'Anéis de cebola empanados.',                                21.00, NULL,  NULL),
 (6,  1, 3, 'Refrigerante Lata','350 ml.',                                                    7.00, NULL,  100),
 (7,  2, 4, 'Margherita',       'Molho de tomate, muçarela de búfala e manjericão.',         59.90, NULL,  NULL),
 (8,  2, 4, 'Calabresa',        'Calabresa fatiada, cebola e azeitonas.',                     54.90, NULL,  NULL),
 (9,  2, 4, 'Quatro Queijos',   'Muçarela, provolone, parmesão e gorgonzola.',               64.90, 59.90, NULL),
 (10, 2, 5, 'Chocolate com Morango','Chocolate ao leite e morangos frescos.',                 62.90, NULL,  NULL),
 (11, 2, 6, 'Refrigerante 2L',  'Garrafa 2 litros.',                                          14.00, NULL,  50);

INSERT INTO cupom (codigo, descricao, tipo, valor, valor_minimo_pedido, desconto_maximo,
                   data_inicio, data_fim, limite_uso, estabelecimento_id) VALUES
 ('BEMVINDO10', '10% de desconto na primeira compra', 'PERCENTUAL', 10.00, 30.00, 20.00,
  '2026-01-01 00:00:00', '2027-12-31 23:59:59', 1000, NULL),
 ('NAPOLI15',   'R$ 15 off na Pizza Napoli',          'VALOR_FIXO', 15.00, 80.00, NULL,
  '2026-01-01 00:00:00', '2027-12-31 23:59:59', NULL, 2);

-- clientes e entregadores via procedures (como a API fará)
CALL sp_cadastrar_cliente('Ana Souza',  'ana.souza@email.com',  @hash, '11988887777', '33333333333', '1998-04-12', @cli1);
CALL sp_cadastrar_cliente('Bruno Alves','bruno.alves@email.com',@hash, '11977776666', '44444444444', '2001-09-30', @cli2);
CALL sp_adicionar_endereco(@cli1, 'Casa', '01311000', 'Rua Augusta', '900', 'Apto 52', 'Consolação',
                           'São Paulo', 'SP', -23.5530000, -46.6560000, 1, @end1);
CALL sp_adicionar_endereco(@cli2, 'Trabalho', '01452000', 'Av. Brigadeiro Faria Lima', '2000', NULL, 'Jardim Paulistano',
                           'São Paulo', 'SP', -23.5770000, -46.6870000, 1, @end2);
CALL sp_cadastrar_entregador('Diego Rocha', 'diego.rocha@email.com', @hash, '11966665555', '55555555555',
                             '12345678901', 'MOTO', 'ABC1D23', @ent1);
CALL sp_cadastrar_entregador('Júlia Costa', 'julia.costa@email.com', @hash, '11955554444', '66666666666',
                             NULL, 'BICICLETA', NULL, @ent2);
UPDATE entregador SET disponivel = 1;

INSERT INTO favorito (cliente_id, estabelecimento_id) VALUES (@cli1, 1), (@cli1, 2), (@cli2, 2);

-- =====================================================================
-- FIM DO SCRIPT
-- =====================================================================
