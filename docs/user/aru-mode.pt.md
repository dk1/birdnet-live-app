# Modo ARU

!!! note "Implementação inicial"
    O modo ARU atualmente cria uma Session de implantação agendada e recuperável, grava ciclos agendados, executa inferência ao vivo durante ciclos ativos, salva clipes de detecção retidos quando esse modo de gravação é selecionado e mostra controles de notificação em primeiro plano no Android. O comportamento em segundo plano no iOS ainda precisa de validação em campo.

ARU (Autonomous Recording Unit) Mode é o fluxo de trabalho em local fixo para implantações acústicas agendadas.

## Fluxo de configuração atual

- **Implantação e áudio**: Insira nome da implantação, ID ARU/estação, observador, local fixo, modo de gravação, formato de gravação e regras de retenção de clipes de detecção. A configuração reutiliza o seletor de microfone compartilhado e mostra o cartão de previsão do tempo quando a consulta meteorológica é permitida.
- **Agenda**: Escolha duração do ciclo, intervalo de repetição, como a implantação deve terminar e um limite de parada por bateria baixa. Você pode parar manualmente, parar após um número fixo de ciclos agendados ou parar em uma data e hora fixas. Os ciclos regulares são ancorados aos limites do relógio, então um ciclo de 10 minutos a cada hora começa na hora cheia, em vez de relativo ao momento em que você iniciou a configuração. O teste de um minuto vem ativado por padrão, começa imediatamente e não consome a contagem de ciclos agendados.
- **Pronto**: Revise a agenda e a estimativa de armazenamento de áudio, depois inicie a implantação.

Ao iniciar, uma Session `SessionType.aru` é salva imediatamente com metadados da agenda ARU para que o estado dos ciclos possa ser recuperado depois.

Exportações JSON e ZIP incluem metadados da implantação ARU. Exportações ZIP agrupam arquivos de gravação por ciclo salvos em `aru_cycles/`.

## Implantação ativa

A tela ARU ativa mostra se a implantação está aguardando, gravando ou concluída. O layout usa quatro abas: **Status** para o estado atual da implantação e detecções, **Espectrograma** para verificar que o áudio está chegando enquanto mantém as detecções abaixo, **Agenda** para os próximos 10 horários de ciclos agendados e **Resumo** para tempo decorrido, duração do áudio gravado e totais de detecções. No Android, implantações ativas mostram uma notificação em primeiro plano com ações Parar e Abrir.

Parar uma implantação abre Session Review para a implantação salva quando os ciclos estão agrupados em uma sessão. Quando a configuração salva cada ciclo como uma Session separada, parar abre a Session do ciclo mais recente.

No iOS, esta implementação inicial deve ser tratada como um fluxo em primeiro plano até que o áudio agendado e o comportamento em segundo plano sejam validados no iOS.

## Ainda planejado

- Validação do comportamento em segundo plano no iOS.
- Suporte completo de reprodução e espectrograma em Session Review para gravações ARU segmentadas.
