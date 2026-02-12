# frozen_string_literal: true

module Brcobranca
  # Modulo para parsear linhas de arquivos de retorno e remessa.
  # Ele e utilizado para definir o layout de cada banco e depois ler as
  # linhas do arquivo de acordo com esse layout.
  #
  # Originalmente baseado em: https://github.com/shairontoledo/parseline
  module ParseLine
    # Armazena os campos definidos para o layout default.
    #
    # @return [Array]
    def parse_values
      @parse_values ||= []
    end

    # Armazena os layouts definidos para o arquivo.
    # Cada layout tem um nome, uma condicao (matcher) e um array de campos (parse_values).
    # O matcher pode ser um Regexp, um Array de caracteres ou uma Proc personalizada.
    #
    # @return [Array]
    def layouts
      @layouts ||= []
    end

    # Define o layout de cada linha do arquivo de acordo com as posicoes
    # de cada campo.
    # Exemplo:
    #     class BancoX < Base
    #       extend ParseLine
    #
    #       fixed_width_layout do |layout|
    #         layout.field :campo1, 0..10
    #         layout.field :campo2, 10..20 do |value|
    #           value.to_i
    #         end
    #       end
    #     end
    def fixed_width_layout
      yield self if block_given?
    end

    # Define um layout condicional. Permite definir multiplos layouts,
    # cada um com sua propria condicao. A condicao pode ser um Regexp
    # ou uma Proc que recebe a linha e retorna true/false.
    #
    # Exemplo:
    #     class BancoX < Base
    #       extend ParseLine
    #
    #       layout :tipo_1, match: /^1/ do |parse|
    #         parse.field :tipo_registro, 0..0
    #         parse.field :campo1, 1..10
    #       end
    #
    #       layout :tipo_3, match: /^3/ do |parse|
    #         parse.field :tipo_registro, 0..0
    #         parse.field :campo_diferente, 1..20
    #       end
    #
    #       # Usando Proc
    #       layout :tipo_4, match: ->(line) { line[0] == '4' } do |parse|
    #         parse.field :tipo_registro, 0..0
    #         parse.field :outro_campo, 1..30
    #       end
    #     end
    #
    # @param [Symbol] name Nome identificador do layout
    # @param [Regexp, Proc] match Condicao para determinar se a linha corresponde a este layout
    # @yield [parse] Bloco para definir os campos do layout usando o metodo `field`
    # @return [void]
    def layout(name = :default, match: nil)
      layouts << { name: name, matcher: match, parse_values: [] }

      @current_layout = layouts.last
      yield(self) if block_given?
      @current_layout = nil
    end

    # Define um campo do layout, indicando o nome do campo,
    # a posicao (range) e opcionalmente um bloco para processar o valor do campo.
    # Exemplo:
    #     parse.field :campo1, 0...10
    #     parse.field :campo2, 10...20, ->(value) { value.to_i }
    #
    # @param [Symbol] field O nome do campo a ser definido.
    # @param [Range] range O intervalo de caracteres onde o campo esta localizado na linha do arquivo.
    # @param [Proc] proc (opcional) Um bloco para processar o valor do campo antes de atribui-lo ao objeto.
    def field(field, range, proc = nil)
      if @current_layout
        @current_layout[:parse_values] << [field, range, proc]
      else
        parse_values << [field, range, proc]
      end
    end

    # Encontra o layout correspondente para uma linha baseado nos matchers definidos.
    # @param [String] line A linha do arquivo
    # @return [Hash, nil] O layout correspondente ou nil se nenhum for encontrado
    def find_layout_for_line(line)
      return nil if layouts.empty?

      layouts.find do |layout|
        line_match?(line, layout[:matcher])
      end
    end

    # Le as linhas de um arquivo e retorna um array de objetos com os campos preenchidos de acordo com o layout definido.
    # Opcoes:
    # - :except => [1, 3] (ignora as linhas 1 e 3)
    # - :except => /regex/ (ignora as linhas que correspondem ao regex)
    # - :length => 100 (considera apenas as linhas com tamanho igual a 100 caracteres)
    #
    # @param [String] filepath O caminho do arquivo a ser lido.
    # @param [Hash] options Opcoes para filtrar as linhas a serem processadas.
    def load_lines(filepath, options = {})
      File.open(filepath).each_with_object([]).with_index(1) do |(line, lines), line_number|
        next if should_skip_line?(line, line_number, options)

        lines << load_line(line)
      end
    end

    # Determina se uma linha deve ser ignorada baseado nas opcoes fornecidas.
    #
    # @param [String] line A linha a ser verificada.
    # @param [Integer] line_number O numero da linha (1-based).
    # @param [Hash] options Opcoes de filtragem incluindo :except e :length.
    # @return [Boolean] true se a linha deve ser ignorada, false caso contrario.
    def should_skip_line?(line, line_number, options)
      return true if line.blank?
      return true unless line_length_valid?(line, options[:length])
      return true if line_excluded?(line, line_number, options[:except])

      false
    end

    # Verifica se uma linha esta na lista de exclusao.
    #
    # @param [String] line A linha a ser verificada.
    # @param [Integer] line_number O numero da linha (1-based).
    # @param [Array, Regexp, nil] exclusion_rule Regra de exclusao (array de numeros ou regex).
    # @return [Boolean] true se a linha deve ser excluida, false caso contrario.
    def line_excluded?(line, line_number, exclusion_rule)
      return false if exclusion_rule.nil?
      return exclusion_rule.include?(line_number) if exclusion_rule.is_a?(Array)
      return exclusion_rule.match?(line) if exclusion_rule.is_a?(Regexp)

      false
    end

    # Processa uma linha do arquivo de acordo com o layout definido e retorna um objeto com os campos preenchidos.
    # Se a linha nao corresponder ao layout definido, uma excecao e levantada.
    # @param [String] line A linha do arquivo a ser processada.
    # @return [Object] Um objeto com os campos preenchidos de acordo com o layout definido.
    def load_line(line)
      instance = new
      layout_config = find_layout_for_line(line) || { parse_values: parse_values }

      layout_config[:parse_values].each do |field_name, range, transformer|
        instance.public_send("#{field_name}=", transform_value(line[range], transformer))
      end

      instance
    rescue StandardError => e
      raise Brcobranca::MalformedLayoutOrLine, "Linha malformada ou layout incorreto: '#{line}', tamanho: #{line.size} " \
                                               "Erro original: (#{e.class}): #{e.message}"
    end

    # Valida o tamanho da linha, se um tamanho esperado for fornecido.
    #
    # @param [String] line A linha a ser validada.
    # @param [Integer, nil] expected_length O tamanho esperado da linha. Se for nil, a validação é ignorada.
    # @return [Boolean]
    def line_length_valid?(line, expected_length = nil)
      return true if expected_length.nil?

      line.to_s.strip.length == expected_length.to_i
    end

    # Verifica se a linha corresponde a um matcher específico.
    #
    # O matcher pode ser um Regexp, um Array de caracteres ou uma Proc personalizada.
    # - Se for um Regexp, a linha é verificada contra o padrão.
    # - Se for um Array, a linha é verificada se o primeiro caractere está incluído no array.
    # - Se for uma Proc, a Proc é chamada com a linha como argumento e deve retornar true ou false.
    #
    # @param [String] line A linha a ser verificada.
    # @param [Regexp, Proc, Array, nil] matcher O matcher a ser usado para verificar a linha.
    # @return [Boolean]
    def line_match?(line, matcher)
      return true if matcher.nil?
      return matcher.match?(line) if matcher.is_a?(Regexp)
      return matcher.include?(line[0]) if matcher.is_a?(Array)
      return matcher.call(line) if matcher.respond_to?(:call)

      false
    end

    # Aplica um transformador ao valor do campo.
    # Se um transformador for fornecido, ele é chamado com o valor do campo e seu resultado é retornado.
    # Caso contrário, o valor original é retornado como string, sem espaços em branco.
    #
    # @param [String] value O valor do campo a ser transformado.
    # @param [Proc, nil] transformer O transformador a ser aplicado ao valor do campo.
    # @return [String] O valor transformado ou o valor original se nenhum transformador for fornecido.
    def transform_value(value, transformer)
      transformer ? transformer.call(value) : value.to_s.strip
    end
  end
end
