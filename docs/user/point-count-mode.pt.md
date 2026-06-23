# Modo Point Count

O Modo Point Count é o fluxo de trabalho estacionário e cronometrado do BirdNET Live.

## Como abrir

Na tela de Início, toque no cartão **Modo Point Count** com o ícone :material-map-marker:.

## Fluxo de configuração

A configuração do Point Count usa quatro etapas.

### 1. Duração e localização

Escolha:

- um dos chips de duração disponíveis
- GPS atual com :material-crosshairs-gps:
- coordenadas manuais com :material-map-marker-plus:
- nenhuma localização com :material-map-marker-off:
- seletor de mapa com :material-map:

A tela de configuração atualiza o GPS quando você volta da caixa de diálogo de permissões do sistema ou das configurações do aplicativo, de modo que uma permissão de localização recém-concedida deve atualizar as coordenadas sem reiniciar o assistente. Essa mesma seção também inclui um cartão de clima. Se o acesso ao clima estiver desativado, o cartão solicita o consentimento de **Permitir consulta de clima**; uma vez ativado, ele apresenta uma prévia do local apenas com um ícone de clima, a temperatura e o vento. O mesmo instantâneo em cache do Open-Meteo é reutilizado quando o Point Count é salvo.

### 2. Parâmetros de inferência

Escolha as configurações de análise por Session, como duração da janela, taxa de inferência, limiar de confiança e o modo do filtro de espécies. Elas partem das suas configurações globais, mas podem ser ajustadas para esta contagem sem alterar seus padrões.

### 3. Dicas de campo

Esta tela apresenta uma breve lista de verificação no aplicativo para percorrer antes de começar.

### 4. Pronto

A tela de pronto resume a duração selecionada e permite começar com :material-play:.

## Tela do Point Count ao vivo

A tela do Point Count ao vivo concentra-se em um painel cronometrado.

### Barra superior

- :material-stop: — encerra o Point Count antecipadamente
- :material-timer: — mostra o tempo restante
- :material-tune: — abre as configurações do Point Count

### Indicadores principais

- barra de progresso da contagem regressiva
- barra de informações compacta com as detecções atuais, a contagem de espécies únicas e o total de detecções
- visualização do espectrograma
- lista de detecções

## Após a contagem

Quando o Point Count termina, o BirdNET Live salva a Session e abre o [Resumo da Session](session-review.md).
