import Config

env = fn name, default -> System.get_env(name, default) end

env_bool = fn name, default ->
  case System.get_env(name) do
    nil -> default
    value -> String.downcase(value) in ["1", "true", "yes", "y", "on"]
  end
end

env_int = fn name, default ->
  case System.get_env(name) do
    nil -> default
    value -> String.to_integer(value)
  end
end

env_list = fn name, default ->
  case System.get_env(name) do
    nil -> default
    value -> value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
  end
end

domain = env.("INSTANCE_DOMAIN", "akkoma.example.com")
static_dir = env.("AKKOMA_STATIC_DIR", "/akkoma/static")
uploads_dir = env.("AKKOMA_UPLOADS_DIR", "/akkoma/uploads")
frontend_name = env.("AKKOMA_FRONTEND_NAME", "soapbox")
frontend_ref = env.("AKKOMA_FRONTEND_REF", "main")
frontend_build_url = env.("AKKOMA_FRONTEND_BUILD_URL", "https://gitlab.com/soapbox-pub/soapbox/-/jobs/artifacts/${ref}/raw/soapbox.zip?job=build")

config :pleroma, Pleroma.Web.Endpoint,
  url: [
    host: domain,
    scheme: env.("AKKOMA_URL_SCHEME", "https"),
    port: env_int.("AKKOMA_URL_PORT", 443)
  ],
  http: [ip: {0, 0, 0, 0}, port: env_int.("AKKOMA_HTTP_PORT", 4000)],
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
  live_view: [signing_salt: System.fetch_env!("LIVE_VIEW_SIGNING_SALT")],
  signing_salt: System.fetch_env!("SIGNING_SALT")

config :pleroma, :instance,
  name: env.("INSTANCE_NAME", "Akkoma"),
  email: env.("INSTANCE_ADMIN_EMAIL", "admin@example.com"),
  notify_email: env.("INSTANCE_NOTIFY_EMAIL", "info@example.com"),
  limit: env_int.("INSTANCE_LIMIT", 5000),
  languages: env_list.("INSTANCE_LANGUAGES", ["ja"]),
  registrations_open: env_bool.("INSTANCE_REGISTRATIONS_OPEN", false),
  federating: env_bool.("INSTANCE_FEDERATING", true),
  public: env_bool.("INSTANCE_PUBLIC", true),
  static_dir: static_dir

config :pleroma, :media_proxy,
  enabled: env_bool.("MEDIA_PROXY_ENABLED", true),
  base_url: env.("MEDIA_PROXY_BASE_URL", "https://akkoma-proxy.example.com"),
  proxy_opts: [
    redirect_on_failure: env_bool.("MEDIA_PROXY_REDIRECT_ON_FAILURE", true)
  ]

config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: env.("DB_USER", "postgres"),
  password: System.fetch_env!("DB_PASS"),
  database: env.("DB_NAME", "postgres"),
  hostname: env.("DB_HOST", "db"),
  port: env_int.("DB_PORT", 5432),
  pool_size: env_int.("DB_POOL_SIZE", 10)

config :web_push_encryption, :vapid_details,
  subject: "mailto:#{env.("INSTANCE_NOTIFY_EMAIL", "info@example.com")}",
  public_key: System.fetch_env!("VAPID_PUBLIC_KEY"),
  private_key: System.fetch_env!("VAPID_PRIVATE_KEY")

config :pleroma, :database, rum_enabled: env_bool.("RUM_ENABLED", false)

config :joken, default_signer: System.fetch_env!("JOKEN_DEFAULT_SIGNER")

config :pleroma,
  configurable_from_database: env_bool.("AKKOMA_CONFIGURABLE_FROM_DATABASE", false)

config :pleroma, Pleroma.Uploaders.Local, uploads: uploads_dir

config :pleroma, Pleroma.Upload,
  filters: [
    Pleroma.Upload.Filter.Exiftool.ReadDescription,
    Pleroma.Upload.Filter.Exiftool.StripMetadata
  ],
  base_url: env.("UPLOADS_BASE_URL", env.("MEDIA_URL", "https://akkoma.example.com/media"))

if env.("AKKOMA_UPLOAD_BACKEND", "s3") == "s3" do
  config :pleroma, Pleroma.Upload, uploader: Pleroma.Uploaders.S3

  config :pleroma, Pleroma.Uploaders.S3,
    bucket: System.fetch_env!("S3_BUCKET"),
    bucket_namespace: System.get_env("S3_BUCKET_NAMESPACE"),
    truncated_namespace: nil,
    streaming_enabled: env_bool.("S3_STREAMING_ENABLED", true)

  config :ex_aws, :s3,
    host: System.fetch_env!("S3_HOST"),
    access_key_id: System.fetch_env!("S3_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("S3_SECRET_ACCESS_KEY"),
    region: env.("S3_REGION", "auto"),
    scheme: env.("S3_SCHEME", "https")
end

config :pleroma, :activitypub,
  unfollow_blocked: env_bool.("ACTIVITYPUB_UNFOLLOW_BLOCKED", true),
  outgoing_blocks: env_bool.("ACTIVITYPUB_OUTGOING_BLOCKS", false),
  blockers_visible: env_bool.("ACTIVITYPUB_BLOCKERS_VISIBLE", true),
  follow_handshake_timeout: env_int.("ACTIVITYPUB_FOLLOW_HANDSHAKE_TIMEOUT", 500),
  note_replies_output_limit: env_int.("ACTIVITYPUB_NOTE_REPLIES_OUTPUT_LIMIT", 5),
  sign_object_fetches: env_bool.("ACTIVITYPUB_SIGN_OBJECT_FETCHES", true),
  authorized_fetch_mode: env_bool.("ACTIVITYPUB_AUTHORIZED_FETCH_MODE", false),
  min_key_refetch_interval: env_int.("ACTIVITYPUB_MIN_KEY_REFETCH_INTERVAL", 86_400),
  max_collection_objects: env_int.("ACTIVITYPUB_MAX_COLLECTION_OBJECTS", 50)

config :pleroma, :manifest,
  icons: [
    %{src: "/logo.svg", type: "image/svg+xml"},
    %{src: "/favicon.png", type: "image/png"}
  ]

config :pleroma, :frontends,
  primary: %{"name" => frontend_name, "ref" => frontend_ref},
  admin: %{"name" => "admin-fe", "ref" => "stable"},
  mastodon: %{"name" => "mastodon-fe", "ref" => "akkoma"},
  pickable: ["#{frontend_name}/#{frontend_ref}"],
  swagger: %{"name" => "swagger-ui", "ref" => "stable", "enabled" => env_bool.("AKKOMA_SWAGGER_ENABLED", true)},
  available: %{
    "pleroma-fe" => %{
      "name" => "pleroma-fe",
      "git" => "https://akkoma.dev/AkkomaGang/pleroma-fe",
      "build_url" => "https://akkoma-updates.s3-website.fr-par.scw.cloud/frontend/${ref}/akkoma-fe.zip",
      "build_dir" => "dist",
      "ref" => "stable"
    },
    "mastodon-fe" => %{
      "name" => "mastodon-fe",
      "git" => "https://akkoma.dev/AkkomaGang/masto-fe",
      "build_url" => "https://akkoma-updates.s3-website.fr-par.scw.cloud/frontend/${ref}/masto-fe.zip",
      "build_dir" => "distribution",
      "ref" => "akkoma"
    },
    "fedibird-fe" => %{
      "name" => "fedibird-fe",
      "git" => "https://akkoma.dev/AkkomaGang/fedibird-fe",
      "build_url" => "https://akkoma-updates.s3-website.fr-par.scw.cloud/frontend/${ref}/fedibird-fe.zip",
      "build_dir" => "distribution",
      "ref" => "akkoma"
    },
    "soapbox" => %{
      "name" => "soapbox",
      "git" => "https://gitlab.com/soapbox-pub/soapbox",
      "bugtracker" => "https://gitlab.com/soapbox-pub/soapbox/-/issues",
      "build_url" => frontend_build_url,
      "build_dir" => "./",
      "ref" => "main"
    },
    "admin-fe" => %{
      "name" => "admin-fe",
      "git" => "https://akkoma.dev/AkkomaGang/admin-fe",
      "build_url" => "https://akkoma-updates.s3-website.fr-par.scw.cloud/frontend/${ref}/admin-fe.zip",
      "build_dir" => "dist",
      "ref" => "stable"
    },
    "swagger-ui" => %{
      "name" => "swagger-ui",
      "git" => "https://github.com/swagger-api/swagger-ui",
      "build_url" => "https://akkoma-updates.s3-website.fr-par.scw.cloud/frontend/swagger-ui.zip",
      "build_dir" => "dist",
      "ref" => "stable"
    }
  }
