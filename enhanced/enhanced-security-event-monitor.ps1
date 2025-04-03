
# enhanced-security-event-monitor.ps1

# ===== CONFIGURATION =====
$ConfigPath = "config.json"

# Function to read configuration from JSON
function Read-Config {
    try {
        if (Test-Path $ConfigPath) {
            Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } else {
            Write-Error "Configuration file '$ConfigPath' not found."
            return $null
        }
    } catch {
        Write-Error "Error reading configuration: $_"
        return $null
    }
}

# Function to write log entries
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = "security-events.log"
    )
    $logLine = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [$Level] $Message"
    Add-Content -Path $LogFile -Value $logLine
}

# Function to write to CSV
function Write-CsvLog {
    param (
        [object[]]$Events,
        [string]$CsvFile
    )
    foreach ($event in $Events) {
        $record = [PSCustomObject]@{
            TimeCreated = $event.TimeCreated
            EventID     = $event.Id
            Provider    = $event.ProviderName
            Message     = ($event.Properties | Out-String).Trim()
        }
        $record | Export-Csv -Path $CsvFile -Append -NoTypeInformation -Encoding UTF8
    }
}

# Function to send Telegram message
function Send-Telegram {
    param(
        [string]$Message,
        [string]$BotToken,
        [string]$ChatId
    )
    try {
        $Url = "https://api.telegram.org/bot$BotToken/sendMessage"
        $Response = Invoke-RestMethod -Uri $Url -Method Post -Body @{ chat_id = $ChatId; text = $Message }
        Write-Log "Telegram message sent."
    } catch {
        Write-Log "Error sending Telegram: $_" -Level "ERROR"
    }
}

# Function to send email message
function Send-Email {
    param(
        [string]$Message,
        [string]$From,
        [string]$To,
        [string]$SmtpServer,
        [int]$SmtpPort,
        [string]$SmtpUser,
        [string]$SmtpPassword
    )
    try {
        $SecurePass = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential ($SmtpUser, $SecurePass)
        Send-MailMessage -From $From -To $To -Subject "Security Event Alert" -Body $Message -SmtpServer $SmtpServer -Port $SmtpPort -UseSsl -Credential $Cred
        Write-Log "Email sent successfully."
    } catch {
        Write-Log "Error sending email: $_" -Level "ERROR"
    }
}

# Function to get readable name for event
function Get-EventName {
    param ([int]$EventID)
    switch ($EventID) {
        4625 { return "❌ Failed Login" }
        4672 { return "🔐 Privileged Logon" }
        4719 { return "⚙️ Policy Change" }
        default { return "ℹ️ Event ID $EventID" }
    }
}

# Function to get security events
function Get-SecurityEvents {
    param(
        [int[]]$EventIds,
        [int]$TimeWindowMinutes,
        [string]$UserFilter = $null,
        [string]$SourceFilter = $null
    )
    $Now = Get-Date
    $SinceTime = $Now.AddMinutes(-$TimeWindowMinutes)
    $Events = Get-WinEvent -LogName Security | Where-Object { $_.Id -in $EventIds -and $_.TimeCreated -gt $SinceTime }

    if ($UserFilter) {
        $Events = $Events | Where-Object { $_.Properties -like "*$UserFilter*" }
    }
    if ($SourceFilter) {
        $Events = $Events | Where-Object { $_.ProviderName -like "*$SourceFilter*" }
    }

    return $Events
}

# Main Execution
$Config = Read-Config
if ($Config) {
    $AlertEvents = Get-SecurityEvents -EventIds $Config.AlertEventIds -TimeWindowMinutes $Config.TimeWindowMinutes -UserFilter $Config.UserFilter -SourceFilter $Config.SourceFilter

    if ($AlertEvents) {
        foreach ($Event in $AlertEvents) {
            $eventName = Get-EventName -EventID $Event.Id
            $msg = "$eventName`n[$($Event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"))]`nSource: $($Event.ProviderName)`n`n$(($Event.Properties | Out-String).Trim())"

            if ($Config.TelegramBotToken -and $Config.TelegramChatId) {
                Send-Telegram -Message $msg -BotToken $Config.TelegramBotToken -ChatId $Config.TelegramChatId
            }
            if ($Config.EnableEmail -eq $true) {
                Send-Email -Message $msg -From $Config.EmailFrom -To $Config.EmailTo -SmtpServer $Config.SmtpServer -SmtpPort $Config.SmtpPort -SmtpUser $Config.SmtpUser -SmtpPassword $Config.SmtpPassword
            }
            Write-Log -Message $msg
        }

        if ($Config.CsvLogFilePath) {
            Write-CsvLog -Events $AlertEvents -CsvFile $Config.CsvLogFilePath
        }

        Write-Host "$($AlertEvents.Count) alert(s) processed."
    } else {
        Write-Host "No critical events detected."
    }
} else {
    Write-Error "Failed to read configuration."
}
