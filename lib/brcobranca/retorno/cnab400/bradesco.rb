# frozen_string_literal: true

module Brcobranca
  module Retorno
    module Cnab400
      # Formato de Retorno CNAB 400
      # Baseado em: https://assets.bradesco/content/dam/portal-bradesco/assets/pessoajuridica/pdf/mpo_arquivos_layout_400P.pdf
      class Bradesco < Brcobranca::Retorno::Cnab400::Base
        extend ParseLine

        # Load lines
        def self.load_lines(file, options = {})
          default_options = { except: /^[09]/ } # Ignora header e trailer
          options = default_options.merge!(options)
          super(file, options)
        end

        # Layout para Registro de Transação - Tipo 1
        layout :tipo1, match: /^1/ do |parse|
          parse.field :codigo_registro, 0..0

          # Identificacao da empresa no banco
          parse.field :carteira, 21..23
          parse.field :agencia_sem_dv, 24..28
          parse.field :cedente_com_dv, 29..36

          # Identificacao do titulo
          parse.field :nosso_numero, 70..81
          parse.field :codigo_ocorrencia, 108..109
          parse.field :data_ocorrencia, 110..115
          parse.field :documento_numero, 116..125

          # Datas e valores
          parse.field :data_vencimento, 146..151
          parse.field :valor_titulo, 152..164

          # Banco recebedor
          parse.field :banco_recebedor, 165..167
          parse.field :agencia_recebedora_com_dv, 168..172
          parse.field :especie_documento, 173..174

          # Valores monetarios
          parse.field :valor_tarifa, 175..187
          parse.field :iof, 214..226
          parse.field :valor_abatimento, 227..239
          parse.field :desconto, 240..252
          parse.field :valor_recebido, 253..265
          parse.field :juros_mora, 266..278
          parse.field :outros_recebimento, 279..291

          # Dados de credito e ocorrencias
          parse.field :data_credito, 295..300
          parse.field :motivo_ocorrencia, 318..327, lambda { |motivos|
            motivos.scan(/.{2}/).reject(&:blank?).reject { |motivo| motivo == '00' }
          }

          parse.field :sequencial, 394..399
        end

        # Layout para Registro de Transação - Tipo 4 – QR CODE
        layout :tipo4, match: /^4/ do |parse|
          parse.field :codigo_registro, 0..0
          parse.field :carteira, 1..3
          parse.field :agencia_sem_dv, 4..8
          parse.field :cedente_com_dv, 9..15
          parse.field :nosso_numero, 16..26
          parse.field :qrcode_emv, 28..104
          parse.field :txid, 105..139
          parse.field :sequencial, 394..399
        end

        def agencia_com_dv
          "#{agencia_sem_dv}-#{agencia_sem_dv.modulo11}"
        end
      end
    end
  end
end
