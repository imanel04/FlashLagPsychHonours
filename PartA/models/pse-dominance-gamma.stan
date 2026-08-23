
data {
  int<lower=0> N;                 // number of data points
  int<lower=0> n_subjects;        // number of subjects
  array[N] int id;                // subject ID  
  vector[N] y;                    // response variable
  
  // Hyperparameters of prior distributions on mean and sd of theta
  real mean_gamma_mu;
  real <lower = 0> mean_gamma_sigma;
  real sd_gamma_mu;
  real <lower = 0> sd_gamma_sigma;
}

parameters {
  real <offset = mean_gamma_mu, multiplier = mean_gamma_sigma> mean_gamma_hat;
  real <offset = sd_gamma_mu, multiplier = sd_gamma_sigma> sd_gamma_hat;
  
  vector<lower = 0> [n_subjects] theta_hat;                                          // placerholder for log-normal subject-specific intercepts
  real<lower=0> sigma_epsilon;                                            // standard deviation of the response variable
}

transformed parameters {
  real <lower = 0> mean_gamma = exp(mean_gamma_hat);            // prior log normal distributed
  real <lower = 0> sd_gamma = exp(sd_gamma_hat);                // prior log normal distributed
  
  real <lower = 0> alpha_theta = mean_gamma^2 / sd_gamma^2;   // transforming mean and sd into model parameters
  real <lower = 0> beta_theta = mean_gamma / sd_gamma^2;    // transforming mean and sd into model parameters
  
  vector<lower = 0> [n_subjects] theta = theta_hat / beta_theta;           // model assumes gamma distributed theta
}


model {
  // Priors
  target += normal_lpdf(sd_gamma_hat | sd_gamma_mu, sd_gamma_sigma);
  target += normal_lpdf(mean_gamma_hat | mean_gamma_mu, mean_gamma_sigma);  
  
  target += gamma_lpdf(theta_hat | alpha_theta, 1);
  target += log(1/sigma_epsilon^2);                    // Jeffreys prior on sigma2
  
  // Likelihood
  target += normal_lpdf(y | theta[id], sigma_epsilon);
}

