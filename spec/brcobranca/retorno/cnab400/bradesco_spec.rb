# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Brcobranca::Retorno::Cnab400::Bradesco do
  let(:arquivo) { File.join(File.dirname(__FILE__), '..', '..', '..', 'arquivos', 'CNAB400BRADESCO.RET') }

  it 'Ignora primeira linha que é header' do
    pagamentos = described_class.load_lines(arquivo)
    pagamento = pagamentos.first
    expect(pagamento.sequencial).to eql('000002')
  end

  it 'Carrega todos os registros (Tipo 1 e Tipo 4)' do
    pagamentos = described_class.load_lines(arquivo)
    expect(pagamentos.size).to eq(8)
  end

  context 'com registros Tipo 1 - Transações de cobrança' do
    let(:pagamentos) { described_class.load_lines(arquivo) }
    let(:registros_tipo1) { pagamentos.select { |p| p.codigo_registro == '1' } }

    it 'Carrega 6 registros tipo 1' do
      expect(registros_tipo1.size).to eq(6)
    end

    it 'Lê corretamente os dados do primeiro registro tipo 1' do
      expect(pagamentos.size).to eq(8)
      pagamento = registros_tipo1.first
      expect(pagamento.agencia_com_dv).to eql('01467-2')
      expect(pagamento.cedente_com_dv).to eql('0019669P')
      expect(pagamento.nosso_numero).to eql('000000000303')
      expect(pagamento.carteira).to eql('009')
      expect(pagamento.data_vencimento).to eql('250515')
      expect(pagamento.valor_titulo).to eql('0000000145000')
      expect(pagamento.banco_recebedor).to eql('237')
      expect(pagamento.agencia_recebedora_com_dv).to eql('04157')
      expect(pagamento.especie_documento).to eql('')
      expect(pagamento.valor_tarifa).to eql('0000000000160')
      expect(pagamento.iof).to eql('0000000000000')
      expect(pagamento.valor_abatimento).to eql('0000000000000')
      expect(pagamento.desconto).to eql('0000000000000')
      expect(pagamento.valor_recebido).to eql('0000000145000')
      expect(pagamento.juros_mora).to eql('0000000000000')
      expect(pagamento.outros_recebimento).to eql('0000000000000')
      expect(pagamento.codigo_ocorrencia).to eql('02')
      expect(pagamento.data_ocorrencia).to eql('150515')
      expect(pagamento.data_credito).to eql('150515')
      expect(pagamento.motivo_ocorrencia).to eql([])
      expect(pagamento.sequencial).to eql('000002')
    end
  end

  context 'com registros Tipo 4 - QR Code PIX' do
    let(:pagamentos) { described_class.load_lines(arquivo) }
    let(:registros_tipo4) { pagamentos.select { |p| p.codigo_registro == '4' } }

    it 'Carrega 2 registros tipo 4' do
      expect(registros_tipo4.size).to eq(2)
    end

    it 'Lê corretamente os dados do primeiro registro tipo 4' do
      pagamento = registros_tipo4.first
      expect(pagamento.codigo_registro).to eql('4')
      expect(pagamento.carteira).to eql('109')
      expect(pagamento.agencia_sem_dv).to eql('04157')
      expect(pagamento.cedente_com_dv).to eql('1234567')
      expect(pagamento.nosso_numero).to eql('00000012345')
      expect(pagamento.qrcode_emv).to eql('00.0123456789.bradesco.pix/qr/v2/cobv/1a2b3c4d5e6f7g8h9i0j1k2l3m4n5oXXXXXXXXX')
      expect(pagamento.txid).to eql('TXID1234567890ABCDEFGHIJKLMNOPQRS00')
      expect(pagamento.sequencial).to eql('000008')
    end

    it 'Lê corretamente os dados do segundo registro tipo 4' do
      pagamento = registros_tipo4.last
      expect(pagamento.codigo_registro).to eql('4')
      expect(pagamento.carteira).to eql('109')
      expect(pagamento.agencia_sem_dv).to eql('04157')
      expect(pagamento.cedente_com_dv).to eql('1234567')
      expect(pagamento.nosso_numero).to eql('00000012345')
      expect(pagamento.qrcode_emv).to eql('00.9876543210.bradesco.pix/qr/v2/cobv/9876543210fedcba0987654321fedcbYYYYYYYY')
      expect(pagamento.txid).to eql('TXIDZYXWVUTSRQPONMLKJIHGFEDCBA98700')
      expect(pagamento.sequencial).to eql('000009')
    end
  end
end
