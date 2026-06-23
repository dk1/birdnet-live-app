# Modo Live

O Modo Live é a forma mais rápida de escutar pelo microfone do telefone e revisar as detecções à medida que aparecem em tempo real.

## Como abrir

Na tela de Início, toque no cartão **Modo Live** com o ícone :material-microphone:.

## Barra superior

A barra superior contém três elementos:

- :material-arrow-left: — sai do Modo Live
- texto de estado central — `Inicializando`, `Carregando modelo`, `Pronto`, `Identificando espécies`, `Pausado` ou `Erro`
- :material-tune: — abre a visualização de Configurações específica do Live

## Botão de ação principal

O grande botão circular na parte inferior central muda de estado:

- :material-microphone: — inicia a escuta
- :material-stop: — para a Session ativa
- :material-play: — retoma a partir de um estado pausado e pronto

## O que você vê durante a escuta

### Espectrograma

O espectrograma rola continuamente enquanto a captura está ativa. Ele mostra o conteúdo de frequência ao longo do tempo, usando a paleta de cores, o tamanho da FFT, a faixa de frequência e a duração configurados nas Configurações.

### Lista de detecções

As detecções recentes aparecem abaixo do espectrograma. Cada linha pode mostrar:

- imagem da espécie
- nome comum
- nome científico opcional
- valor de confiança

Toque em uma linha de espécie para abrir a sobreposição de detalhes da espécie.

### Barra de informações da Session

A linha de informação compacta abaixo do espectrograma resume a Session atual, por exemplo:

- detecções visíveis no momento
- contagem de espécies únicas (`spp`)
- total de detecções (`det`)
- duração decorrida
- tamanho estimado da gravação quando a gravação está ativada

## Comportamento de gravação

A gravação é controlada nas [Configurações](settings.md).

- **Completo** grava toda a Session.
- **Apenas detecções** grava clipes em torno das detecções.
- **Desativado** desativa a gravação.

Ao parar o Modo Live, o BirdNET Live salva a Session e abre o [Resumo da Session](session-review.md).
