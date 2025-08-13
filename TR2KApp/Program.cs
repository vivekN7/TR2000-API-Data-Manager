using TR2KApp.Components;
using TR2KBlazorLibrary.Logic.Repositories;
using TR2KBlazorLibrary.Logic.Services;
using TR2KBlazorLibrary.Models.DatabaseModels;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add HttpClient
builder.Services.AddHttpClient();

// Add database services
builder.Services.AddScoped<ISqliteConnectionFactory, SqliteConnectionFactory>();

// Add repositories
builder.Services.AddScoped<IGenericRepository<ImportLog>, GenericRepository<ImportLog>>();
builder.Services.AddScoped<IGenericRepository<Operator>, GenericRepository<Operator>>();
builder.Services.AddScoped<IGenericRepository<Plant>, GenericRepository<Plant>>();
builder.Services.AddScoped<IGenericRepository<PCS>, GenericRepository<PCS>>();
builder.Services.AddScoped<IGenericRepository<Issue>, GenericRepository<Issue>>();

// Add business services
builder.Services.AddScoped<TR2000ApiService>();
builder.Services.AddScoped<DataImportService>();
builder.Services.AddScoped<ApiResponseDeserializer>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
}


app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
